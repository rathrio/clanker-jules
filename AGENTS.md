This repository contains the source code for Jules, a terminal-based AI assistant powered by the Google Gemini API.

## Core Components
- `jules.rb`: The main entry point and chat loop. It handles user input, manages the conversation history, and communicates with the Gemini API.
- `message.rb`: Handles the formatting of messages into the structure required by the Gemini API.
- `tool.rb`: Defines the tools Jules can use (e.g., executing bash commands, reading/writing files).
- `raw-messages.json`: A dynamically generated file that stores the raw conversation history for debugging.
- `AGENTS.md`: This file, providing repository-specific context to Jules.

## Key Environment Variables
- `GOOGLE_GENERATIVE_AI_API_KEY`: Required to authenticate with the Gemini API.

## Language and Setup
- Written in Ruby.
- Uses standard libraries (`json`, `net/http`, `uri`).
