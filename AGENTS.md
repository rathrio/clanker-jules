This repository contains the source code for Jules, a terminal-based AI assistant powered by the Google Gemini API.

## Core Components
- `jules.rb`: The main entry point and chat loop. It handles user input, manages the conversation history, and communicates with the Gemini API.
- `message.rb`: Handles the formatting of messages into the structure required by the Gemini API.
- `tool.rb`: Defines the tools Jules can use (e.g., executing bash commands, reading/writing files).
- `AGENTS.md`: This file, providing repository-specific context to Jules.

## Development Guidelines
- Before implementing a new tool, always review the implementation of existing tools (e.g., `tools/edit_tool.rb`) to ensure consistency.

## Key Environment Variables
- `GOOGLE_GENERATIVE_AI_API_KEY`: Required to authenticate with the Gemini API.

## Linting
- This project uses RuboCop for linting.
- Run `bundle exec rubocop -A` to auto-correct offenses.
- The configuration is in `.rubocop.yml`. Method length and class length rules are disabled.
