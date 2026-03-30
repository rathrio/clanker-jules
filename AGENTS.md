This repository contains the source code for Jules, a terminal-based AI assistant that supports multiple LLM providers.

## Core Components
- `jules.rb`: The main entry point and chat loop. It handles user input, manages the conversation history, and communicates with the configured provider.
- `terminal.rb`: The terminal interactions (poor man's TUI).
- `message.rb`: Handles the formatting of messages into provider-specific structures (Gemini and OpenAI formats).
- `tool.rb`: Defines the tools Jules can use (e.g., executing bash commands, reading/writing files). The individual tools themselves are in the `tools/` subdirectory.
- `skill.rb`: Defines the skill loading code.
- `provider.rb`: Defines the provider module and interface. Check `providers/` for the actual provider implementations

## Development Guidelines
- Before implementing a new tool, always review the implementation of existing tools (e.g., `tools/edit_tool.rb`) to ensure consistency.
- No external gem dependencies —  all API communication uses `net/http` from the standard library.
- Use rubocop for linting and minitest for testing. Tests serve as documented examples. Avoid global test state and make sure that a test case in itself is readable and documents the whole flow. Avoid testing implementation details. Avoid mocking if you can.
- ALWAYS run tests and linting after major changes (`bundle exec rake ci`). You don't need to run it before committing because there should be a commit hook taking care of this.
