defmodule C100GPU.MixProject do
  use Mix.Project

  def project do
    [
      app: :c100_gpu,
      version: "0.1.0",
      elixir: "~> 1.15",
      deps: [
        {:nx_iree, github: "mlainez/nx_iree", branch: "jetson-nvk"},
        {:exla, "~> 1.0", only: :test}
      ]
    ]
  end

  def application, do: [extra_applications: [:logger]]
end
