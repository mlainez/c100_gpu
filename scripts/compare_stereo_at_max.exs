# Controlled comparison at the accepted C100 cap; normal policy is restored.
gpu = "/sys/class/devfreq/57000000.gpu"
minimum = File.read!(gpu <> "/min_freq") |> String.trim()
maximum = File.read!(gpu <> "/max_freq") |> String.trim()
governor = File.read!(gpu <> "/governor") |> String.trim()

unless maximum == "921600000" and governor == "simple_ondemand",
  do: raise("expected the accepted 921.6 MHz cap and simple_ondemand governor")

env_keys = ["STEREO_RUNTIME_ROOT", "STEREO_SCRIPT", "STEREO_BUNDLE", "STEREO_PAUSE_MS"]
saved_env = Map.new(env_keys, &{&1, System.get_env(&1)})

bundles =
  case System.get_env("STEREO_COMPARE_BUNDLES") do
    nil ->
      [{"baseline", "/root/nxiree/stereo.bin"}, {"affinity", "/root/nxiree/stereo-affinity.bin"}]

    paths ->
      paths
      |> String.split(",", trim: true)
      |> Enum.map(fn path -> {Path.basename(path), path} end)
  end

if bundles == [], do: raise("STEREO_COMPARE_BUNDLES must contain at least one bundle path")
for {_, path} <- bundles, do: File.stat!(path)
script = System.get_env("STEREO_COMPARE_SCRIPT", "/root/nxiree/stereo-run.exs")
File.stat!(script)

try do
  File.write!(gpu <> "/min_freq", maximum)
  IO.puts("CONTROLLED_GPU_MIN=" <> String.trim(File.read!(gpu <> "/min_freq")))
  System.put_env("STEREO_RUNTIME_ROOT", "/root/nxiree-stereo")
  System.put_env("STEREO_SCRIPT", script)
  System.put_env("STEREO_PAUSE_MS", "0")

  for {name, bundle} <- bundles do
    IO.puts("CONTROLLED_COMPILER=#{name}")
    System.put_env("STEREO_BUNDLE", bundle)
    Code.eval_file("/root/nxiree/stereo-board-run.exs")
  end
after
  File.write!(gpu <> "/min_freq", minimum)

  for {key, value} <- saved_env do
    if value, do: System.put_env(key, value), else: System.delete_env(key)
  end

  IO.puts("RESTORED_GPU_MIN=" <> String.trim(File.read!(gpu <> "/min_freq")))
  IO.puts("RESTORED_GOVERNOR=" <> String.trim(File.read!(gpu <> "/governor")))
end
