# UX Findings Report for Jules

I've reviewed the codebase with a focus on User Experience (UX). Here are my findings across several key areas:

### 1. Input Experience (✅ Fixed)
*   ~**Single-line Input Limitation:** The current prompt (`input = gets`) restricts users to single-line entries because pressing `Enter` immediately submits the message. This makes it very difficult for users to paste code blocks, write multi-paragraph prompts, or format their thoughts clearly.~
    * *Fixed by switching to `Readline.readline` for bash-like history and arrow-key navigation. Added a `/multi` command for writing multi-paragraph prompts or pasting code (submitted via `Ctrl+D`).*
*   ~**No Built-in Commands:** There is no way to reset the conversation context (e.g., a `/clear` command) without entirely exiting and restarting the script.~
    * *Fixed by introducing standard slash commands: `/help` (list commands), `/clear` (wipe history), `/multi` (multiline input), and `/exit`.*
*   ~**Lack of Typing/Thinking Indicators:** When the user submits a message, the terminal simply hangs while waiting for the Gemini API to respond. There is no spinner, loading animation, or visual indicator to reassure the user that a request is actively being processed.~
    * *Fixed by adding a separate thread that prints an animated braille spinner (`⠋ thinking...`) while waiting for the HTTP request to complete.*

### 2. Output & Display
*   **Raw Markdown Rendering:** The model's responses often include Markdown (bolding, code blocks, etc.), but `puts "jules: #{text}"` just prints the raw characters to the terminal. Adding syntax highlighting or basic Markdown formatting would significantly improve readability.
*   ~**Formatting Inconsistencies:** Because `jules: ` is prepended only to the first line of a potentially multi-line output block, long responses or code snippets look disjointed and don't visually group well with the speaker label.~
    * *Fixed by printing a single, bold `jules:` label on its own line before emitting response text, creating cleaner visual blocks for multi-line output.*
*   ~**Lack of Color/Styling:** Everything is printed in the terminal's default text color. Distinguishing user input, AI responses, tool executions, and errors with different colors would make the conversation much easier to parse.~
    * *Fixed by introducing a lightweight `UI` module with ANSI escape codes mapping to the Dracula color palette. User prompts are Bold Green, the AI label is Bold Purple, system messages are Cyan, and background tools/spinners are faded Comment Gray.*

### 3. Tool Execution Transparency
*   ~**Opaque Data Structures:** When a tool is executed, it logs exactly what Ruby sees (e.g., `jules: Executing tool: bash with args: {"command"=>"ls -la"}`). Displaying a raw Ruby hash is jarring for an end user.~
  * *Fixed by adding a custom `render_execution` method to each tool, providing cleanly formatted, human-readable output instead of raw JSON arguments (e.g., `Running: ls -la`).*
*   **Hidden Tool Results:** The assistant can read files or run bash commands, but the *results* of those operations are captured and sent directly to the API in the background. The user is kept in the dark about what the tools are actually returning or modifying until the model decides to summarize it.
*   **Bash Standard Error Leakage:** The `BashTool` uses backticks (`` `...` ``) to execute commands. This captures `stdout` for the model, but `stderr` (errors) will leak directly into the user's terminal uncaptured, which will mess up the chat interface.

### 4. Stability & Error Handling
*   **Abrupt API Crashes:** If the Gemini API returns an error (due to rate limits, context size limits, or network issues), the app dumps the raw JSON and throws an unhandled exception (`raise 'no candidates'`). This crashes the session completely instead of failing gracefully and letting the user try again.
*   **Corruptible Conversation State (Ctrl+C):** If a user presses `Ctrl+C` while the assistant is executing a tool, the script rescues the `Interrupt` and resets `has_unsent_tool_results = false`. However, Gemini enforces a strict alternation rule: a `functionCall` *must* be followed by a `functionResponse`. By dropping the tool result, the conversation history becomes invalid, and the very next message sent to the API will trigger a fatal `400 Bad Request` error.
