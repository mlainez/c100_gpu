Code.require_file("../scripts/board_gpu_log.exs", __DIR__)

defmodule C100GPU.BoardLogTest do
  use ExUnit.Case, async: true

  test "rejects channel ring timeouts even when the process returns success" do
    message =
      "[21016.628276] nouveau 57000000.gpu: iree-benchmark-[4904]: nv50cal_space: -110"

    assert C100GPU.BoardLog.errors(message) == [message]
  end

  test "retains initialization and compute error detection without matching normal startup" do
    messages = [
      "nouveau 57000000.gpu: pmu:hpq: timeout waiting for queue ready",
      "nouveau 57000000.gpu: gr: init failed, -110",
      "nouveau 57000000.gpu: gr: TRAP"
    ]

    log = Enum.join(["nouveau 57000000.gpu: NVIDIA GM20B (12b000a1)" | messages], "\n")
    assert C100GPU.BoardLog.errors(log) == messages
  end
end
