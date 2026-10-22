# Bounded diagnostic only: distinguish CPU feeding latency from GPU work.
# The child guard bounds execution and watches GPU errors; the benchmark
# checks thermal limits.
policies = Path.wildcard("/sys/devices/system/cpu/cpufreq/policy*")
if policies == [], do: raise("no CPU frequency policy")
saved = Map.new(policies, &{&1, File.read!(&1 <> "/scaling_governor")})

for policy <- policies do
  max_khz =
    (policy <> "/scaling_max_freq") |> File.read!() |> String.trim() |> String.to_integer()

  unless max_khz <= 1_479_000, do: raise("CPU cap exceeds C100 validated limit")
end

try do
  for policy <- policies do
    File.write!(policy <> "/scaling_governor", "performance")
    IO.puts("CPU_PROBE_GOVERNOR=#{String.trim(File.read!(policy <> "/scaling_governor"))}")
  end

  Code.eval_file(System.get_env("C100_GPU_GUARD", Path.join(__DIR__, "stereo_board_run.exs")))
after
  for {policy, governor} <- saved do
    File.write!(policy <> "/scaling_governor", governor)
    IO.puts("CPU_RESTORED_GOVERNOR=#{String.trim(File.read!(policy <> "/scaling_governor"))}")
  end
end
