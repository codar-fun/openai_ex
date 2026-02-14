defmodule Example.CLI.Main do
  @moduledoc """
  Escript entry point for the CLI application.
  """

  def main(args) do
    ensure_finch_started()

    case Example.CLI.run(args) do
      :ok ->
        :ok

      {:error, _reason} ->
        System.halt(1)
    end
  end

  defp ensure_finch_started do
    Application.ensure_all_started(:finch)
  end
end
