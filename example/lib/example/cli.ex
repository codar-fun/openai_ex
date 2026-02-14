defmodule Example.CLI do
  @moduledoc """
  Example CLI demonstrating the OpenAI Responses API via openai_ex.

  The Responses API is OpenAI's newest API for generating responses,
  designed to be a more flexible alternative to Chat Completions.
  """

  alias OpenaiEx.Responses

  @default_model "gpt-4o-mini"

  @doc """
  Creates an OpenAI client from the OPENAI_API_KEY environment variable.
  """
  def new_client do
    api_key = System.get_env("OPENAI_API_KEY")

    if is_nil(api_key) or api_key == "" do
      {:error, "OPENAI_API_KEY environment variable not set"}
    else
      {:ok, OpenaiEx.new(api_key)}
    end
  end

  @doc """
  Ask a question using the Responses API (non-streaming).

  ## Example

      iex> {:ok, client} = Example.CLI.new_client()
      iex> {:ok, response} = Example.CLI.ask(client, "What is 2+2?")
      iex> response["output"]
      "4"
  """
  def ask(openai, prompt, opts \\ []) do
    model = Keyword.get(opts, :model, @default_model)

    request = %{
      model: model,
      input: prompt
    }

    Responses.create(openai, request)
  end

  @doc """
  Ask a question using the Responses API with streaming output.

  Prints chunks to stdout as they arrive.

  ## Example

      iex> {:ok, client} = Example.CLI.new_client()
      iex> Example.CLI.ask_stream(client, "Tell me a joke")
  """
  def ask_stream(openai, prompt, opts \\ []) do
    model = Keyword.get(opts, :model, @default_model)

    request = %{
      model: model,
      input: prompt
    }

    case Responses.create(openai, request, stream: true) do
      {:ok, %{body_stream: body_stream}} ->
        IO.write("\nResponse: ")

        try do
          output = process_stream(body_stream)
          IO.write("\n\n")
          {:ok, output}
        rescue
          exception ->
            IO.write("\n")
            {:error, exception}
        catch
          kind, reason ->
            IO.write("\n")
            {:error, {kind, reason}}
        end

      {:error, error} ->
        {:error, error}
    end
  end

  defp process_stream(stream) do
    stream
    |> Stream.flat_map(fn
      events when is_list(events) -> events
      event -> [event]
    end)
    |> Stream.map(&parse_sse_event/1)
    |> Enum.reduce("", fn event, acc ->
      case output_content_type(event) do
        :delta ->
          case get_text_content(event) do
            nil ->
              acc

            text ->
              IO.write(text)
              acc <> text
          end

        :final ->
          # Some providers repeat the full final text in a "...done" event.
          if acc == "" do
            case get_text_content(event) do
              nil ->
                acc

              text ->
                IO.write(text)
                acc <> text
            end
          else
            acc
          end

        :none ->
          if error_event?(event) do
            IO.puts(:stderr, "
Error event: #{inspect(event)}")
          end

          acc
      end
    end)
  end

  # OpenaiEx.HttpSse emits items like:
  #   %{data: %{...decoded json...}}
  #   %{event: "someEventId", data: %{...decoded json...}}
  defp parse_sse_event(%{data: data}) when is_map(data), do: data
  defp parse_sse_event(%{event: _event_id, data: data}) when is_map(data), do: data
  defp parse_sse_event(data) when is_map(data), do: data
  defp parse_sse_event(_), do: %{}

  defp output_content_type(%{"type" => "response.output_text.delta"}), do: :delta
  defp output_content_type(%{"type" => "response.output_text.done"}), do: :final
  defp output_content_type(%{"type" => "response.output_text"}), do: :final
  defp output_content_type(_), do: :none

  defp error_event?(%{"type" => type}) when type in ["error", "response.error"], do: true
  defp error_event?(%{"error" => _}), do: true
  defp error_event?(_), do: false

  defp get_text_content(%{"delta" => delta}) when is_binary(delta), do: delta
  defp get_text_content(%{"text" => text}) when is_binary(text), do: text
  defp get_text_content(_), do: nil

  @doc """
  Run the CLI with command line arguments.
  """
  def run(args) do
    case args do
      [] ->
        IO.puts("Usage: example_cli <prompt>")
        IO.puts("\nSet OPENAI_API_KEY environment variable before running.")
        {:error, :no_args}

      prompts ->
        prompt = Enum.join(prompts, " ")

        case new_client() do
          {:ok, openai} ->
            case ask_stream(openai, prompt) do
              {:ok, _output} ->
                :ok

              {:error, %OpenaiEx.Error{} = error} ->
                IO.puts(:stderr, "\nError: #{Exception.message(error)}")
                {:error, error}

              {:error, error} ->
                IO.puts(:stderr, "\nError: #{inspect(error)}")
                {:error, error}
            end

          {:error, message} ->
            IO.puts(:stderr, "Error: #{message}")
            {:error, :no_api_key}
        end
    end
  end
end
