# Example CLI - OpenAI Responses API

A simple CLI application demonstrating how to use `openai_ex` to call the OpenAI Responses API.

## Setup

1. Set your OpenAI API key:
   ```bash
   export OPENAI_API_KEY="your-api-key-here"
   ```

2. Install dependencies:
   ```bash
   cd example
   mix deps.get
   ```

## Usage

### Build and run as escript

```bash
mix escript.build
./example_cli "What is the capital of France?"
```

### Run directly with Mix

```bash
mix run --no-halt -- "Your question here"
```

### Run in interactive mode

```bash
iex -S mix
iex> Example.CLI.ask("What is Elixir?")
```

## Examples

```bash
# Simple question
./example_cli "Explain quantum computing in one sentence"

# Streaming response (default)
./example_cli "Write a haiku about programming"
```

## Code Structure

- `lib/example/cli.ex` - Core CLI logic and Response API calls
- `lib/example/cli/main.ex` - Escript entry point for command-line execution
