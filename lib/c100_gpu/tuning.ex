defmodule C100GPU.Tuning do
  @moduledoc """
  IREE tuning measured on the C100's Tegra210 GM20B GPU.

  Select the matmul spec with `iree_tuning: {C100GPU.Tuning, :maxwell_matmul}`.
  It uses 64x64x8 tiles, 16x8 threads and a single buffering stage.
  """

  @behaviour NxIREE.Tuning
  @external_resource Path.expand("../../priv/tuning/maxwell_matmul.mlir", __DIR__)
  @matmul File.read!(@external_resource)

  @impl true
  def fetch(:maxwell_matmul), do: {:ok, @matmul, ["vulkan-spirv"]}
  def fetch(_), do: :error
end
