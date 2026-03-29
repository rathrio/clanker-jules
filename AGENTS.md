This repository contains the source code for Jules, a terminal-based AI assistant that supports multiple LLM providers.

## Core Components
- `jules.rb`: The main entry point and chat loop. It handles user input, manages the conversation history, and communicates with the configured provider.
- `message.rb`: Handles the formatting of messages into provider-specific structures (Gemini and OpenAI formats).
- `tool.rb`: Defines the tools Jules can use (e.g., executing bash commands, reading/writing files).
- `providers/`: Provider implementations. Each provider handles API communication and response parsing.
  - `base_provider.rb`: Shared interface module included by all providers.
  - `gemini.rb`: Google Gemini API provider (direct HTTP, no external dependencies).
  - `open_router.rb`: OpenRouter provider (OpenAI-compatible API, access to many models).
- `AGENTS.md`: This file, providing repository-specific context to Jules.

## Development Guidelines
- Before implementing a new tool, always review the implementation of existing tools (e.g., `tools/edit_tool.rb`) to ensure consistency.
- No external gem dependencies —  all API communication uses `net/http` from the standard library.

## Linting
- This project uses RuboCop for linting.
- Run `bundle exec rubocop -A` to auto-correct offenses. Always run it after major changes.
- The configuration is in `.rubocop.yml`. Method length and class length rules are disabled.
