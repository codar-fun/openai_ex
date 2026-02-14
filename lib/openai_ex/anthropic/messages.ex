defmodule OpenaiEx.Anthropic.Messages do
  @moduledoc """
  This module provides an implementation of Anthropic's Messages API.

  API reference: https://platform.claude.com/docs/en/api/messages/create
  """
  alias OpenaiEx.{Http, HttpSse}

  @api_fields [
    :model,
    :max_tokens,
    :messages,
    :metadata,
    :stop_sequences,
    :stream,
    :system,
    :temperature,
    :thinking,
    :tool_choice,
    :tools,
    :top_k,
    :top_p,
    :service_tier,
  ]

  @ep_url "/v1/messages"

  @doc """
  Creates a new Messages API request.

  Example usage:

      iex> _request = OpenaiEx.Anthropic.Messages.new(model: "claude-sonnet-4-5", max_tokens: 512, messages: [%{role: "user", content: "Hello"}])
      %{max_tokens: 512, messages: [%{content: "Hello", role: "user"}], model: "claude-sonnet-4-5"}
  """
  def new(args = [_ | _]) do
    args |> Enum.into(%{}) |> new()
  end

  def new(args = %{model: _, max_tokens: _, messages: _}) do
    args |> Map.take(@api_fields)
  end

  @doc """
  Calls Anthropic's `messages.create` endpoint.

  See https://platform.claude.com/docs/en/api/messages/create for details.
  """
  def create!(openai = %OpenaiEx{}, params = %{}, stream: true) do
    openai |> create(params, stream: true) |> Http.bang_it!()
  end

  def create(openai = %OpenaiEx{}, params = %{}, stream: true) do
    request_body = params |> Map.take(@api_fields) |> Map.put(:stream, true)
    openai |> HttpSse.post(@ep_url, json: request_body)
  end

  def create!(openai = %OpenaiEx{}, params = %{}) do
    openai |> create(params) |> Http.bang_it!()
  end

  def create(openai = %OpenaiEx{}, params = %{}) do
    openai |> Http.post(@ep_url, json: params |> Map.take(@api_fields))
  end
end
