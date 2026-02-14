defmodule Example.CLI.MixProject do
  use Mix.Project

  def project do
    [
      app: :example_cli,
      version: "0.1.0",
      elixir: "~> 1.14",
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      escript: escript()
    ]
  end

  def application do
    [
      extra_applications: [:logger]
    ]
  end

  defp deps do
    [
      {:openai_ex, path: ".."}
    ]
  end

  defp escript do
    [main_module: Example.CLI.Main]
  end
end
