defmodule C100GPU.Bench.MixProject do
  use Mix.Project

  def project do
    [
      app: :c100_gpu_bench,
      version: "0.1.0",
      elixir: "~> 1.15",
      deps: [
        {:c100_gpu, path: ".."},
        {:exla, "~> 1.0"},
        {:nx, "~> 1.0"},
        {:axon, "~> 0.9"},
        {:bumblebee, "~> 0.8"}
      ]
    ]
  end
end
