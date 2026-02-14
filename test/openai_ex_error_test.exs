defmodule OpenaiEx.ErrorTest do
  use ExUnit.Case, async: true

  alias OpenaiEx.Error

  test "status_error handles map error payloads" do
    response = %{headers: [{"x-request-id", "req_123"}]}
    body = %{"error" => %{"message" => "Not found", "code" => "not_found"}}

    error = Error.status_error(404, response, body)

    assert error.kind == :not_found
    assert error.message == "Not found"
    assert error.body == %{"message" => "Not found", "code" => "not_found"}
    assert error.request_id == ["req_123"]
  end

  test "status_error handles string error payloads" do
    response = %{headers: [{"x-request-id", "req_456"}]}
    body = %{"error" => "url.not_found"}

    error = Error.status_error(404, response, body)

    assert error.kind == :not_found
    assert error.message == "url.not_found"
    assert error.body == %{"error" => "url.not_found"}
    assert error.request_id == ["req_456"]
  end
end
