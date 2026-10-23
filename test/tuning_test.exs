defmodule C100GPU.TuningTest do
  use ExUnit.Case, async: true

  test "the Maxwell spec changes generated matmul code" do
    template = Nx.template({128, 128}, :f32)
    flags = [iree_compiler_flags: ["--iree-hal-target-backends=vulkan-spirv"]]

    plain = NxIREE.export(&Nx.dot/2, [template, template], flags) |> :erlang.binary_to_term()

    tuned =
      NxIREE.export(
        &Nx.dot/2,
        [template, template],
        flags ++ [iree_tuning: {C100GPU.Tuning, :maxwell_matmul}]
      )
      |> :erlang.binary_to_term()

    assert byte_size(tuned.bytecode) > 0
    refute tuned.bytecode == plain.bytecode
  end

  test "every spec is served for the Vulkan backend" do
    for name <- [:maxwell_matmul, :yolov5s_maxwell, :yolov5s_maxwell_f16] do
      assert {:ok, spec, ["vulkan-spirv"]} = C100GPU.Tuning.fetch(name)
      assert spec =~ "iree_codegen.tuning_spec_entrypoint"
    end

    assert C100GPU.Tuning.fetch(:unknown) == :error
  end

  @tag :hardware
  test "the tuned matmul matches the CPU on the selected Vulkan device" do
    {:ok, devices} = NxIREE.list_devices("vulkan")
    match = System.get_env("NXIREE_DEVICE_MATCH", "")
    gpu = Enum.find(devices, &String.contains?(&1.uri, match))
    assert gpu, "no Vulkan device matches #{inspect(match)}"

    a = Nx.iota({128, 128}, type: :f32, backend: Nx.BinaryBackend) |> Nx.divide(1000)

    got =
      Nx.Defn.jit(&Nx.dot/2,
        compiler: NxIREE.Compiler,
        iree_runtime_options: [device: gpu],
        iree_tuning: {C100GPU.Tuning, :maxwell_matmul}
      ).(a, a)
      |> Nx.backend_transfer(Nx.BinaryBackend)

    want = Nx.dot(a, a)
    assert Nx.subtract(got, want) |> Nx.abs() |> Nx.reduce_max() |> Nx.to_number() < 1.0e-2
  end
end
