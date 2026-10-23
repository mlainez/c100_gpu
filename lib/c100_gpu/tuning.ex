defmodule C100GPU.Tuning do
  @moduledoc """
  IREE tuning measured on the C100's Tegra210 GM20B GPU.

  Select the matmul spec with `iree_tuning: {C100GPU.Tuning, :maxwell_matmul}`.
  It uses 64x64x8 tiles, 16x8 threads and a single buffering stage.

  `:yolov5s_maxwell` overrides two matmul families of YOLOv5s compiled with
  im2col convolutions and the padded ONNX graph from
  `nx_iree/bench/yolo`; see the README.
  """

  @behaviour NxIREE.Tuning
  @specs Map.new([:maxwell_matmul, :yolov5s_maxwell], fn name ->
           {name, File.read!(Path.expand("../../priv/tuning/#{name}.mlir", __DIR__))}
         end)

  @external_resource Path.expand("../../priv/tuning/maxwell_matmul.mlir", __DIR__)
  @external_resource Path.expand("../../priv/tuning/yolov5s_maxwell.mlir", __DIR__)

  @impl true
  def fetch(name) when is_map_key(@specs, name), do: {:ok, Map.fetch!(@specs, name), ["vulkan-spirv"]}
  def fetch(_), do: :error
end
