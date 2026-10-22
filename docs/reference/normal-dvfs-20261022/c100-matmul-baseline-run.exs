if root = System.get_env("STEREO_RUNTIME_ROOT") do
  for app <- ~w(complex telemetry nx nx_iree),
      do: Code.append_path(Path.join([root, "lib", app, "ebin"]))
end
{:ok, _} = Application.ensure_all_started(:nx)
%{n: n, models: models} = System.fetch_env!("STEREO_BUNDLE") |> File.read!() |> :erlang.binary_to_term()
{:ok, devices} = NxIREE.list_devices("vulkan")
device =
  case {System.get_env("NXIREE_DEVICE_URI"), devices} do
    {nil, [device]} -> device
    {uri, _} when is_binary(uri) -> Enum.find(devices, &(&1.uri == uri)) || raise("device missing")
    _ -> raise("select NXIREE_DEVICE_URI")
  end
IO.puts("DEVICE=#{device.uri}")
pause_ms = System.get_env("MATMUL_PAUSE_MS", "100") |> String.to_integer()
IO.puts("PAUSE_MS=#{pause_ms}")
frequency = fn ->
  for path <- Path.wildcard("/sys/class/devfreq/*gpu/cur_freq"),
      do: {path, File.read!(path) |> String.trim()}
end
guard = fn ->
  for path <- Path.wildcard("/sys/class/thermal/thermal_zone*/temp") do
    if File.read!(path) |> String.trim() |> String.to_integer() >= 70_000,
      do: raise("thermal guard")
  end
end
for name <- [:default, :c100_tuning] do
  model = NxIREE.load_exported(Map.fetch!(models, name), device: device)
  IO.puts("MODEL=#{name} written_inputs=#{inspect(model.module.written_inputs)}")
  for b_value <- [2.0, 3.0] do
    args = for value <- [1.0, b_value], do: Nx.broadcast(Nx.tensor(value, type: :f32), {n, n})
    input_bytes = Enum.map(args, &Nx.to_binary/1)
    expected = Nx.broadcast(Nx.tensor(n * b_value, type: :f32), {n, n}) |> Nx.to_binary()
    resident = Enum.map(args, &Nx.backend_copy(&1, {NxIREE.Backend, device: device}))
    try do
      run = fn -> NxIREE.run(model, resident) |> Nx.backend_transfer(Nx.BinaryBackend) |> Nx.to_binary() end
      guard.()
      if run.() != expected, do: raise("incorrect matmul")
      times = for _ <- 1..5 do
        guard.()
        before_freq = frequency.()
        {us, output} = :timer.tc(run)
        if output != expected, do: raise("incorrect repeated matmul")
        IO.puts("FREQUENCY before=#{inspect(before_freq)} after=#{inspect(frequency.())}")
        Process.sleep(pause_ms)
        us / 1000
      end
      unless Enum.map(resident, &Nx.to_binary/1) == input_bytes, do: raise("input modified")
      IO.puts("MATMUL model=#{name} n=#{n} b=#{b_value} ms=#{inspect(times)} includes=invoke_and_readback inputs_unchanged=true")
    after
      Enum.each(resident, &Nx.backend_deallocate/1)
    end
  end
end
IO.puts("MATMUL_PASS")
