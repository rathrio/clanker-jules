This repository contains the source code for Jules, a terminal-based AI assistant written in Ruby.

## Core Components
- `bin/jules`: Executable entry point. Parses CLI flags (`--provider`, `--model`, `--list-models`), builds the provider, loads tools/skills, constructs the system prompt, and starts the chat loop.
- `lib/jules.rb`: Main library loader that wires all core components.
- `lib/jules/chat.rb`: Main chat runtime loop (input handling, slash commands, tool execution flow, provider round-trips, chat log persistence).
- `lib/jules/terminal.rb`: Terminal UX helpers (prompting, rendering output, spinner, slash-command parsing).
- `lib/jules/message.rb`: Message abstraction and provider-specific serialization (Gemini and OpenAI-compatible formats).
- `lib/jules/provider.rb`: Provider interface + provider registry/factory.
- `lib/jules/providers/`: Provider implementations (`gemini_provider.rb`, `openai_compatible_provider.rb`).
- `lib/jules/tool.rb`: Tool registry/dispatch and declaration formatting.
- `lib/jules/tools/`: Individual tool implementations.
- `lib/jules/skill.rb`: Skill loading/parsing from `~/.agents/skills/*/SKILL.md`.

## Development Guidelines
- Before implementing a new tool, review existing tool implementations for conventions and error handling (for example, `lib/jules/tools/edit_tool.rb`).
- No LLM SDK gems: API communication should use Ruby standard library primitives (`net/http`, etc.).
- Use minitest for tests and rubocop for linting.
- Prefer readable, flow-oriented tests over implementation-detail tests.
- Avoid global test state and unnecessary mocking.
- After major changes, run:
  - `bundle exec rake test`
  - `bundle exec rubocop`
  - or `bundle exec rake ci`
