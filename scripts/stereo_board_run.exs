Code.require_file("board_gpu_log.exs", __DIR__)

gpu_errors = fn ->
  {dmesg, 0} = System.cmd("dmesg", [])
  C100GPU.BoardLog.errors(dmesg)
end

baseline = gpu_errors.()
diagnostic? = System.get_env("C100_GPU_DIAGNOSTIC") == "1"

if baseline != [] do
  Enum.each(baseline, &IO.puts/1)

  unless diagnostic?, do: raise("GPU errors already present; refusing benchmark")
  IO.puts("DIAGNOSTIC_BASELINE_GPU_ERRORS=#{length(baseline)}")
end

gpu = "/sys/class/devfreq/57000000.gpu"
IO.puts("BOOT_ID=" <> String.trim(File.read!("/proc/sys/kernel/random/boot_id")))
IO.puts("GOVERNOR=" <> String.trim(File.read!(gpu <> "/governor")))
IO.puts("GPU_MAX=" <> String.trim(File.read!(gpu <> "/max_freq")))
IO.puts("GPU_MIN=" <> String.trim(File.read!(gpu <> "/min_freq")))
erts = :code.root_dir() |> to_string() |> Path.join("erts-*") |> Path.wildcard() |> hd()

script = System.get_env("STEREO_SCRIPT", "/root/nxiree/stereo-run.exs")

eval =
  ~s|{ok,_}=application:ensure_all_started(elixir), 'Elixir.Code':eval_file(<<#{inspect(script)}>>), halt().|

args = [
  "+S",
  "2:2",
  "-boot",
  "/srv/erlang/releases/0.1.0/start_clean",
  "-boot_var",
  "RELEASE_LIB",
  "/srv/erlang/lib",
  "-noshell",
  "-eval",
  eval
]

{executable, args} =
  case System.get_env("C100_GPU_COMMAND_FILE") do
    nil -> {erts <> "/bin/erlexec", args}
    file -> file |> File.read!() |> :erlang.binary_to_term([:safe])
  end

timeout_ms = System.get_env("C100_GPU_TIMEOUT_MS", "120000") |> String.to_integer()
unless timeout_ms in 1..120_000, do: raise("GPU command timeout must be 1..120000 ms")

env = [
  {~c"ROOTDIR", ~c"/srv/erlang"},
  {~c"BINDIR", String.to_charlist(erts <> "/bin")},
  {~c"EMU", ~c"beam"},
  {~c"PROGNAME", ~c"erl"},
  {~c"NVK_I_WANT_A_BROKEN_VULKAN_DRIVER", ~c"1"},
  {~c"STEREO_RUNTIME_ROOT",
   System.get_env("STEREO_RUNTIME_ROOT", "/root/nxiree") |> String.to_charlist()},
  {~c"STEREO_BUNDLE",
   System.get_env("STEREO_BUNDLE", "/root/nxiree/stereo.bin") |> String.to_charlist()},
  {~c"STEREO_MIN_AVAILABLE_KB", ~c"2000000"},
  {~c"VK_DRIVER_FILES", false},
  {~c"VK_ICD_FILENAMES", false}
]

port =
  Port.open(
    {:spawn_executable, executable},
    [:binary, :exit_status, :stderr_to_stdout, args: args, env: env]
  )

{:os_pid, os_pid} = Port.info(port, :os_pid)
IO.puts("CHILD_PID=#{os_pid}")
deadline = System.monotonic_time(:millisecond) + timeout_ms

stop = fn ->
  System.cmd("kill", ["-9", Integer.to_string(os_pid)])

  receive do
    {^port, {:exit_status, _}} -> :ok
  after
    5000 -> Port.close(port)
  end
end

collect = fn collect, acc, next_check ->
  now = System.monotonic_time(:millisecond)
  errors = if now >= next_check, do: gpu_errors.() -- baseline, else: []
  next_check = if now >= next_check, do: now + 250, else: next_check

  cond do
    errors != [] ->
      Enum.each(errors, &IO.puts/1)
      stop.()
      {acc, :gpu_error}

    now >= deadline ->
      stop.()
      {acc, :timeout}

    true ->
      receive do
        {^port, {:data, data}} ->
          IO.write(data)
          collect.(collect, acc <> data, next_check)

        {^port, {:exit_status, rc}} ->
          {acc, rc}
      after
        max(0, min(next_check, deadline) - now) -> collect.(collect, acc, next_check)
      end
  end
end

{out, rc} = collect.(collect, "", System.monotonic_time(:millisecond))
IO.puts("CHILD_EXIT=#{rc}")
errors = gpu_errors.()

Enum.each(errors, &IO.puts/1)
IO.puts("GPU_ERRORS=#{length(errors)}")
new_errors = errors -- baseline
IO.puts("NEW_GPU_ERRORS=#{length(new_errors)}")

marker = System.get_env("STEREO_SUCCESS_MARKER", "STEREO_PATH_PASS")

if rc != 0 or new_errors != [] or not String.contains?(out, marker),
  do: raise("stereo path benchmark failed")

IO.puts(if(diagnostic?, do: "BOARD_DIAGNOSTIC_PASS", else: "BOARD_STEREO_PASS"))
