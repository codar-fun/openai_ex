defmodule Example.CLI do
  @moduledoc """
  Example CLI demonstrating the OpenAI Responses API via openai_ex.

  The Responses API is OpenAI's newest API for generating responses,
  designed to be a more flexible alternative to Chat Completions.
  """

  alias OpenaiEx.{Anthropic.Messages, Chat.Completions, ChatMessage, Responses}

  @default_model "gpt-5-nano"

  @doc """
  Creates an API client from environment variables.
  If OPENAI_API_ENDPOINT points to Anthropic, builds an Anthropic-configured client.
  """
  def new_client do
    api_key = System.get_env("OPENAI_API_KEY")
    api_endpoint = System.get_env("OPENAI_API_ENDPOINT")

    if is_nil(api_key) or api_key == "" do
      {:error, "OPENAI_API_KEY environment variable not set"}
    else
      openai = build_client(api_key, api_endpoint)

      {:ok, openai}
    end
  end

  defp build_client(api_key, api_endpoint) do
    if is_binary(api_endpoint) and api_endpoint != "" and
         String.contains?(String.downcase(api_endpoint), "anthropic.com") do
      OpenaiEx.new_anthropic(api_key, base_url: api_endpoint)
    else
      OpenaiEx.new(api_key)
      |> maybe_with_api_endpoint(api_endpoint)
    end
  end

  defp maybe_with_api_endpoint(openai, api_endpoint)
       when is_binary(api_endpoint) and api_endpoint != "" do
    OpenaiEx.with_base_url(openai, api_endpoint)
  end

  defp maybe_with_api_endpoint(openai, _), do: openai

  @doc """
  Ask a question using the Responses API (non-streaming).

  ## Example

      iex> {:ok, client} = Example.CLI.new_client()
      iex> {:ok, response} = Example.CLI.ask(client, "What is 2+2?")
      iex> response["output"]
      "4"
  """
  def ask(openai, prompt, opts \\ []) do
    model = Keyword.get(opts, :model, default_model(openai))

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
    model = Keyword.get(opts, :model, default_model(openai))

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
        if fallback_to_chat_completions?(error) do
          case ask_chat_completion(openai, prompt, model) do
            {:ok, fallback_output} ->
              IO.write("\nResponse: #{fallback_output}\n\n")
              {:ok, fallback_output}

            {:error, fallback_error} ->
              {:error, fallback_error}
          end
        else
          {:error, error}
        end
    end
  end

  @doc """
  Ask a question using the Chat Completions API (non-streaming).
  """
  def ask_completion(openai, prompt, opts \\ []) do
    model = Keyword.get(opts, :model, default_model(openai))
    ask_chat_completion(openai, prompt, model)
  end

  @doc """
  Ask a question using Anthropic's Messages API (non-streaming).
  """
  def ask_message(openai, prompt, opts \\ []) do
    model = Keyword.get(opts, :model, default_model(openai))

    request =
      Messages.new(%{
        model: model,
        max_tokens: 1024,
        messages: [%{role: "user", content: prompt}]
      })

    case Messages.create(openai, request) do
      {:ok, response} ->
        {:ok, extract_anthropic_message_text(response)}

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

  defp default_model(%OpenaiEx{base_url: base_url}) when is_binary(base_url) do
    case System.get_env("OPENAI_API_MODEL") do
      model when is_binary(model) and model != "" ->
        model

      _ ->
        if String.contains?(base_url, "moonshot.cn"), do: "moonshot-v1-8k", else: @default_model
    end
  end

  defp default_model(_), do: System.get_env("OPENAI_API_MODEL") || @default_model

  defp fallback_to_chat_completions?(%OpenaiEx.Error{status_code: 404, body: body})
       when is_map(body) do
    body["error"] == "url.not_found" and is_binary(body["url"]) and
      String.ends_with?(body["url"], "/responses")
  end

  defp fallback_to_chat_completions?(_), do: false

  defp ask_chat_completion(openai, prompt, model) do
    request = %{
      model: model,
      messages: [ChatMessage.user(prompt)]
    }

    case Completions.create(openai, request) do
      {:ok, response} ->
        {:ok, extract_chat_completion_text(response)}

      {:error, error} ->
        retry_chat_completion_with_v1(openai, request, error)
    end
  end

  defp retry_chat_completion_with_v1(
         openai = %OpenaiEx{},
         request,
         error = %OpenaiEx.Error{status_code: 404, body: body}
       )
       when is_map(body) do
    with true <- body["error"] == "url.not_found",
         true <- is_binary(body["url"]),
         true <- String.ends_with?(body["url"], "/chat/completions"),
         false <- String.ends_with?(openai.base_url, "/v1") do
      v1_openai =
        openai
        |> OpenaiEx.with_base_url(String.trim_trailing(openai.base_url, "/") <> "/v1")

      case Completions.create(v1_openai, request) do
        {:ok, response} -> {:ok, extract_chat_completion_text(response)}
        {:error, retry_error} -> {:error, retry_error}
      end
    else
      _ -> {:error, error}
    end
  end

  defp retry_chat_completion_with_v1(_openai, _request, error), do: {:error, error}

  defp extract_chat_completion_text(%{"choices" => [%{"message" => message} | _]}) do
    extract_message_content(message)
  end

  defp extract_chat_completion_text(%{choices: [%{message: message} | _]}) do
    extract_message_content(message)
  end

  defp extract_chat_completion_text(response), do: inspect(response)

  defp extract_message_content(%{"content" => content}) when is_binary(content), do: content
  defp extract_message_content(%{content: content}) when is_binary(content), do: content

  defp extract_message_content(%{"content" => content}) when is_list(content),
    do: extract_content_parts(content)

  defp extract_message_content(%{content: content}) when is_list(content),
    do: extract_content_parts(content)

  defp extract_message_content(message), do: inspect(message)

  defp extract_content_parts(parts) do
    parts
    |> Enum.map(&extract_content_part/1)
    |> Enum.reject(&(&1 == ""))
    |> Enum.join("")
  end

  defp extract_content_part(%{"text" => text}) when is_binary(text), do: text
  defp extract_content_part(%{text: text}) when is_binary(text), do: text
  defp extract_content_part(_), do: ""

  defp extract_anthropic_message_text(%{"content" => content}) when is_list(content),
    do: extract_content_parts(content)

  defp extract_anthropic_message_text(%{content: content}) when is_list(content),
    do: extract_content_parts(content)

  defp extract_anthropic_message_text(response), do: inspect(response)

  @doc """
  Run the CLI with command line arguments.
  """
  def run(args) do
    {options, prompts, invalid_options} =
      OptionParser.parse(args,
        switches: [completion: :boolean, response: :boolean, message: :boolean]
      )

    cond do
      invalid_options != [] ->
        print_usage()
        {:error, :invalid_options}

      Enum.count([options[:completion], options[:response], options[:message]], & &1) > 1 ->
        IO.puts(:stderr, "Error: choose only one of --completion, --response, or --message.")
        print_usage()
        {:error, :conflicting_options}

      prompts == [] ->
        print_usage()
        {:error, :no_args}

      true ->
        prompt = Enum.join(prompts, " ")
        api_mode = resolve_api_mode(options)
        request_opts = []

        case new_client() do
          {:ok, openai} ->
            run_prompt(openai, prompt, api_mode, request_opts)

          {:error, message} ->
            IO.puts(:stderr, "Error: #{message}")
            {:error, :no_api_key}
        end
    end
  end

  defp run_prompt(openai, prompt, :completion, request_opts) do
    case ask_completion(openai, prompt, request_opts) do
      {:ok, output} ->
        IO.puts("\nResponse: #{output}\n")
        :ok

      {:error, %OpenaiEx.Error{} = error} ->
        IO.puts(:stderr, "\nError: #{Exception.message(error)}")
        {:error, error}

      {:error, error} ->
        IO.puts(:stderr, "\nError: #{inspect(error)}")
        {:error, error}
    end
  end

  defp run_prompt(openai, prompt, :response, request_opts) do
    case ask_stream(openai, prompt, request_opts) do
      {:ok, _output} ->
        :ok

      {:error, %OpenaiEx.Error{} = error} ->
        IO.puts(:stderr, "\nError: #{Exception.message(error)}")
        {:error, error}

      {:error, error} ->
        IO.puts(:stderr, "\nError: #{inspect(error)}")
        {:error, error}
    end
  end

  defp run_prompt(openai, prompt, :message, request_opts) do
    case ask_message(openai, prompt, request_opts) do
      {:ok, output} ->
        IO.puts("\nResponse: #{output}\n")
        :ok

      {:error, %OpenaiEx.Error{} = error} ->
        IO.puts(:stderr, "\nError: #{Exception.message(error)}")
        {:error, error}

      {:error, error} ->
        IO.puts(:stderr, "\nError: #{inspect(error)}")
        {:error, error}
    end
  end

  defp resolve_api_mode(options) do
    cond do
      options[:message] -> :message
      options[:completion] -> :completion
      true -> :response
    end
  end

  defp print_usage do
    IO.puts("Usage: example_cli [--response | --completion | --message] <prompt>")
    IO.puts("  --response    Use the Responses API (default)")
    IO.puts("  --completion  Use the Chat Completions API")
    IO.puts("  --message     Use Anthropic's Messages API")
    IO.puts("\nSet OPENAI_API_MODEL to choose the model.")
    IO.puts("\nSet OPENAI_API_KEY environment variable before running.")
  end
end
