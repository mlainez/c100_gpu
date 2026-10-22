defmodule C100GPU.CpuLoadProbe do
  @moduledoc """
  Runs a guarded benchmark while supervised OTP crypto workers use the CPU.

  This is a diagnostic workload, not a model of a particular application.
  Workers run in the caller's BEAM, independently of the benchmark child.
  CPU accounting includes all caller-BEAM threads and existing activity.
  No clock, governor, firmware or GPU policy is changed here.
  """

  def run(workers, fun) when workers in 0..2 and is_function(fun, 0) do
    {:ok, _} = Application.ensure_all_started(:crypto)
    {:ok, supervisor} = Task.Supervisor.start_link()
    parent = self()
    token = make_ref()
    payload = :binary.copy(<<0x5A>>, 65_536)

    try do
      tasks =
        for _ <- List.duplicate(:worker, workers) do
          Task.Supervisor.async_nolink(supervisor, fn ->
            send(parent, {token, :ready, self()})

            receive do
              {^token, :go} -> hash_loop(payload, token, 0)
            end
          end)
        end

      for %{pid: pid} <- tasks do
        receive do
          {^token, :ready, ^pid} -> :ok
        after
          5000 -> raise "CPU load worker did not become ready"
        end
      end

      IO.puts("CPU_LOAD_BEGIN workers=#{workers} workload=otp_crypto_sha256 block_bytes=65536")
      cpu_start = cpu_ticks()
      start = System.monotonic_time(:microsecond)
      for %{pid: pid} <- tasks, do: send(pid, {token, :go})

      try do
        fun.()
      after
        for %{pid: pid} <- tasks, do: send(pid, {token, :stop})
        blocks = tasks |> Enum.map(&Task.await(&1, 5000)) |> Enum.sum()
        wall_us = System.monotonic_time(:microsecond) - start
        ticks = cpu_ticks() - cpu_start

        IO.puts(
          "CPU_LOAD_RESULT workers=#{workers} blocks=#{blocks} wall_ms=#{wall_us / 1000} cpu_ticks=#{ticks} source=caller_beam_all_threads includes=guard_startup_measurement_output_validation_and_existing_application_activity"
        )
      end
    after
      Supervisor.stop(supervisor)
      IO.puts("CPU_LOAD_STOPPED")
    end
  end

  defp hash_loop(payload, token, blocks) do
    receive do
      {^token, :stop} -> blocks
    after
      0 ->
        :crypto.hash(:sha256, payload)
        hash_loop(payload, token, blocks + 1)
    end
  end

  defp cpu_ticks do
    [_, fields] = String.split(File.read!("/proc/self/stat"), ") ", parts: 2)
    fields = String.split(fields)
    String.to_integer(Enum.at(fields, 11)) + String.to_integer(Enum.at(fields, 12))
  end
end
