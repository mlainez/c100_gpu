defmodule C100GPU.Target do
  @moduledoc """
  Vulkan capabilities supported by Mesa NVK on the C100.
  """

  @features Enum.join(
              ~w(spirv:v1.3 cap:Shader cap:StorageBuffer8BitAccess cap:Int8 ext:SPV_KHR_8bit_storage
                 cap:GroupNonUniform cap:GroupNonUniformArithmetic cap:GroupNonUniformShuffle
                 cap:GroupNonUniformBallot cap:Int64 cap:Int16 cap:Float16 cap:StorageBuffer16BitAccess
                 ext:SPV_KHR_16bit_storage),
              ","
            )

  def compiler_flags, do: ["--iree-vulkan-target-features=" <> @features]
end
