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

## Voice & UX
- Jules is a neonoir detective running in a terminal. All user-facing strings (help text, hints, errors, prompts, stage directions) stay in this register.
- Terminal concepts map to the metaphor: cursor/typewriter/reel (the stage), case file/transcript (conversation), coat/lineup (models), evidence binder (file picker), command index (slash picker), slide across / walk out / cut the scene (input actions).
- Flavor-text pools (stage directions, entrance lines, transitions, etc.) live in `lib/jules/script.rb`. Add new variants there rather than hardcoding strings in `terminal.rb`.
- Don't costume things that must stay scannable: `Error:` labels, raw debug output, ANSI escape constants, tool verbs in `TOOL_STAGE_DIRECTIONS`.

## Development Guidelines
- Before implementing a new tool, review existing tool implementations for conventions and error handling (for example, `lib/jules/tools/edit_tool.rb`).
- No LLM SDK gems: API communication should use Ruby standard library primitives (`net/http`, etc.).
- Use minitest for tests and rubocop for linting.
- Tests must verify observable behavior (return values, side effects, output), NOT internal implementation details like which methods were called, what arguments were passed to shell commands, or how code is structured internally.
- Do NOT mock or stub unless absolutely necessary. If a tool shells out to `rg`, `git`, or another CLI tool that is available in the test environment, run it for real against temp files instead of stubbing `Open3.capture3`.
- Never mock Ruby internals like `Kernel.rand`, `IO.console`, or `is_a?`.
- Never assert on the exact command-line arguments passed to external tools — test the result, not the invocation.
- If a test requires more than one level of stubbing/mocking, it is testing implementation details. Rewrite it or don't write it.
- Avoid global test state.
- After major changes, run:
  - `bundle exec rake test`
  - `bundle exec rubocop`
  - or `bundle exec rake ci`
  - To check coverage: `COVERAGE=true bundle exec rake test`
