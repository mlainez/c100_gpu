Code.require_file("/var/home/marc/Projects/c100_gpu/lib/c100_gpu/tuning.ex")
Logger.configure(level: :warning)
n = 1024
t = Nx.template({n, n}, :f32)
flags = ["--iree-hal-target-backends=vulkan-spirv"]
models =
  for {name, tuning} <- [{:default, []}, {:c100_tuning, [iree_tuning: {C100GPU.Tuning, :maxwell_matmul}]}], into: %{} do
    binary = NxIREE.export(&Nx.dot/2, [t, t], [iree_compiler_flags: flags] ++ tuning)
    IO.puts("EXPORTED #{name} #{byte_size(binary)} bytes")
    {name, binary}
  end
File.write!("/tmp/c100-matmul-baseline.bin", :erlang.term_to_binary(%{n: n, models: models}))
