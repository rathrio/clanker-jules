This repository contains the source code for Jules, a terminal-based AI assistant that supports multiple LLM providers.

## Core Components
- `bin/jules`: The executable entry point and chat loop. It handles user input, manages conversation history, and communicates with the configured provider.
- `lib/jules.rb`: Main library loader that wires core components.
- `lib/jules/terminal.rb`: Terminal interactions (poor man's TUI).
- `lib/jules/message.rb`: Formats messages into provider-specific structures (Gemini and OpenAI-compatible formats).
- `lib/jules/tool.rb`: Defines the tool registry/dispatch. Individual tools live in `lib/jules/tools/`.
- `lib/jules/skill.rb`: Skill loading code.
- `lib/jules/provider.rb`: Provider module and interface. Provider implementations are in `lib/jules/providers/`.

## Development Guidelines
- Before implementing a new tool, always review existing tool implementations (e.g., `lib/jules/tools/edit_tool.rb`) to ensure consistency.
- No external gem dependencies —  all API communication uses `net/http` from the standard library.
- Use rubocop for linting and minitest for testing. Tests serve as documented examples. Avoid global test state and make sure that a test case in itself is readable and documents the whole flow. Avoid testing implementation details. Avoid mocking if you can.
- ALWAYS run tests and linting after major changes (`bundle exec rake ci`). You don't need to run it before committing because there should be a commit hook taking care of this.
