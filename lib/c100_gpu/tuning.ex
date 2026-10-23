defmodule C100GPU.Tuning do
  @moduledoc """
  IREE tuning specs measured on the C100's Tegra210 GM20B GPU.

  Each spec is returned as `iree-compile` flags for `:iree_compiler_flags`:

      flags = C100GPU.Target.compiler_flags() ++ C100GPU.Tuning.compiler_flags(:maxwell_matmul)
      Nx.Defn.jit(&Nx.dot/2, compiler: NxIREE.Compiler, iree_compiler_flags: flags)

    * `:maxwell_matmul` - 64x64x8 tiles, 16x8 threads and a single buffering
      stage, for plain matmuls.
    * `:yolov5s_maxwell` - two matmul families of YOLOv5s in f32, compiled
      with im2col convolutions; see the README.
    * `:yolov5s_maxwell_f16` - the f16 YOLOv5s graph from
      `nx_iree/bench/yolo`, compiled with f16 accumulators and Winograd.
  """

  @specs ~w(maxwell_matmul yolov5s_maxwell yolov5s_maxwell_f16)a

  for spec <- @specs do
    @external_resource Path.expand("../../priv/tuning/#{spec}.mlir", __DIR__)
  end

  @doc "Returns the compiler flags that apply the named tuning spec."
  def compiler_flags(spec) when spec in @specs do
    ["--iree-codegen-transform-dialect-library=" <> path(spec)]
  end

  @doc "Returns the path of the named tuning spec."
  def path(spec) when spec in @specs do
    Path.join([:code.priv_dir(:c100_gpu), "tuning", "#{spec}.mlir"])
  end
end
