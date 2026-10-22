defmodule C100GPU.BoardLog do
  @moduledoc false

  def errors(log) do
    log
    |> String.split("\n")
    |> Enum.filter(
      &Regex.match?(
        ~r/nouveau.*(timeout|timed out|failed|TRAP|FAULT|(?:nv50)?cal_space:\s*-\d+|error fencing pushbuf)/i,
        &1
      )
    )
  end
end
