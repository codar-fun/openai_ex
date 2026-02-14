# AGENTS.md - Guide for AI Coding Agents

This document provides essential context for AI coding agents working in this repository.

## Project Overview

`OpenaiEx` is a community-maintained Elixir library for the OpenAI API. It closely follows the structure of the official OpenAI Python API client, making it easy to understand and reuse existing documentation.

- **Language**: Elixir (~> 1.12)
- **Build Tool**: Mix
- **HTTP Client**: Finch
- **JSON**: Jason
- **License**: Apache-2.0

---

## Build/Lint/Test Commands

### Dependencies
```bash
mix deps.get          # Install dependencies
mix deps.compile      # Compile dependencies
mix deps.unlock --check-unused  # Check for unused dependencies
```

### Compilation
```bash
mix compile                      # Compile the project
mix compile --warnings-as-errors # Treat warnings as errors (CI strict mode)
```

### Formatting
```bash
mix format                 # Format all code
mix format --check-formatted  # Check if code is formatted (CI)
```

### Linting & Static Analysis
```bash
mix credo      # Run Credo linter
mix dialyzer   # Run Dialyzer static analysis
```

### Testing
```bash
mix test                           # Run all tests
mix test --warnings-as-errors      # Run tests treating warnings as errors
mix test test/openai_ex_test.exs   # Run single test file
mix test test/path/to/test.exs:42  # Run specific test at line 42
```

### Documentation
```bash
mix docs    # Generate documentation (docs environment)
```

---

## Code Style Guidelines

### Formatting
- **Line length**: 120 characters max (configured in `.formatter.exs`)
- **Indentation**: 2 spaces (Elixir standard)
- Run `mix format` before committing

### Naming Conventions

| Element | Convention | Example |
|---------|------------|---------|
| Functions/Variables | snake_case | `create_completion`, `chat_request` |
| Modules/Protocols | PascalCase | `OpenaiEx.Chat.Completions` |
| Constants | SCREAMING_SNAKE | `@api_fields` |
| Private functions | No prefix | Use `defp` |
| Internal API | Underscore prefix | `_for_azure`, `_identity` |

### Function Naming Patterns
- **`new/1`** or **`new/2`**: Constructors/factory functions
- **`create/2`**: API create operations (returns `{:ok, result}` or `{:error, reason}`)
- **`create!/2`**: Bang version that raises on error
- **`retrieve/2`**, **`list/2`**, **`update/2`**, **`delete/2`**: CRUD operations
- **`bang_it!/1`**: Converts `{:ok, val}/{:error, err}` to value or raise

### Imports and Aliases
```elixir
# Prefer alias for repeated module references
alias OpenaiEx.{Http, HttpSse}

# Use @moduledoc for module documentation
@moduledoc """
Module description here.
"""

# Use @doc for function documentation
@doc """
Function description with examples.
"""

# Use @doc false for internal functions not meant for public use
@doc false
```

---

## Types and Specs

### Struct Definitions
Define structs with `defstruct` at module top:
```elixir
defstruct token: nil,
          organization: nil,
          base_url: "https://api.openai.com/v1"
```

### API Field Lists
Group API fields in module attributes:
```elixir
@api_fields [
  :messages,
  :model,
  :temperature,
  :max_tokens
]
```

---

## Error Handling

### Return Value Pattern
- **Normal functions**: Return `{:ok, result}` or `{:error, reason}` tuples
- **Bang functions** (ending with `!`): Return result directly or raise exception

```elixir
# Non-bang: returns tuple
def create(openai, request) do
  # Returns {:ok, response} or {:error, error}
end

# Bang: raises on error
def create!(openai, request) do
  openai |> create(request) |> Http.bang_it!()
end
```

### Exception Structure
Custom exceptions use `defexception`:
```elixir
defmodule OpenaiEx.Error do
  defexception [:status_code, :message, :body, :kind]
end
```

### Error Kinds
- `:bad_request`, `:authentication`, `:permission_denied`, `:not_found`
- `:rate_limit`, `:internal_server`, `:api_connection`, `:api_timeout`

---

## Project Structure

```
lib/openai_ex/
├── openai_ex.ex          # Main module, struct definition, core API
├── application.ex        # OTP Application callback
├── http.ex               # HTTP wrapper (public interface)
├── http_finch.ex         # Finch HTTP implementation
├── http_sse.ex           # Server-Sent Events streaming
├── error.ex              # Custom exception definitions
├── chat_completions.ex   # Chat Completions API
├── chat_message.ex       # Message builders
├── embeddings.ex         # Embeddings API
├── files.ex              # Files API
├── models.ex             # Models API
├── images.ex             # Image generation
├── audio/                # Audio APIs (transcription, translation, speech)
│   ├── speech.ex
│   ├── translations.ex
│   └── transcriptions.ex
├── beta/                 # Beta/preview APIs
│   ├── assistants.ex
│   ├── threads.ex
│   └── threads_runs.ex
└── ...                   # Other API modules
```

---

## API Module Pattern

Most API modules follow this pattern:

```elixir
defmodule OpenaiEx.SomeResource do
  @moduledoc """
  Implementation of the OpenAI [resource] API.
  Reference: https://platform.openai.com/docs/api-reference/...
  """
  
  alias OpenaiEx.Http
  
  @api_fields [:field1, :field2]
  @ep_url "/resource"
  
  def new(args) do
    args |> Map.take(@api_fields)
  end
  
  def create(openai = %OpenaiEx{}, request) do
    openai |> Http.post(@ep_url, json: request)
  end
  
  def create!(openai = %OpenaiEx{}, request) do
    openai |> create(request) |> Http.bang_it!()
  end
  
  # retrieve, list, update, delete follow similar patterns
end
```

---

## Key Design Principles

1. **Python API Alignment**: Mirror the official Python client structure
2. **Functional Patterns**: Prefer pipe operators, pattern matching, and pure functions
3. **Explicit Error Handling**: Use `{:ok, result}/{:error, reason}` tuples
4. **Livebook-First**: Support direct instantiation without app config
5. **Streaming Support**: SSE-based streaming for chat completions

### Functional Style Examples
```elixir
# Prefer pipes
openai
|> Http.post(url, json: request)
|> handle_response()

# Pattern matching in function heads
def create(openai = %OpenaiEx{}, request = %{model: _, messages: _}) do
  # ...
end

# Use with for chaining operations
with {:ok, response} <- api_call(),
     {:ok, parsed} <- parse(response) do
  {:ok, parsed}
end
```

---

## Testing

- Tests use ExUnit with `doctest` for documentation examples
- Main test file: `test/openai_ex_test.exs`
- Livebooks in `notebooks/` serve as executable documentation/tests
- Run tests before committing: `mix test`

---

## Commit Guidelines

Use conventional commit format:
```
<type>: <description>

Co-authored-by: <AI Model> <model@llm-context>
```

Types: `feat`, `fix`, `docs`, `refactor`, `test`, `chore`
