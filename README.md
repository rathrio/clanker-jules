# Jules

Jules is a terminal-based AI assistant written in Ruby. It supports multiple LLM
providers and can use local tools to inspect files, search code, run shell
commands, and edit your workspace from chat.

I wrote this for myself for pedagogical reasons to demystify coding
agents. No LLM gems are used here - just the Ruby standard library against
inference endpoints. I started out by implementing the core loop (in `bin/jules`)
by hand against the Gemini API. The only tools I wrote by hand are `WriteTool`,
`ReadTool` and `BashTool`. From that point on I let `jules` edit itself to get
to where it is now.

## Installation (macOS)

### 1) Install required dependencies with Homebrew

Jules shells out to several CLI tools. Install these first:

```bash
brew install ruby glow ripgrep ast-grep
```

Notes:
- `glow` is used to render markdown in the terminal.
- `ripgrep` (`rg`) powers search/glob tools.
- `ast-grep` powers structural code search (`find_code`).
- `patch` is also used by Jules; on macOS it is usually already available from system tools.

### 2) Install Ruby gems

From the project directory:

```bash
bundle install
```

## Configure provider API keys

Set environment variables for whichever provider you use:

- Gemini: `GOOGLE_GENERATIVE_AI_API_KEY`
- OpenRouter/OpenAI-compatible: `OPENROUTER_API_KEY`
- Kiro preset: `KIRO_API_KEY` (or uses fallback for local proxy)

Optional:
- `JULES_PROVIDER` (default: `gemini`)
- `JULES_MODEL` (provider-specific model override)

## Make `jules` available on your PATH

From the repo root:

```bash
chmod +x bin/jules
ln -sf "$(pwd)/bin/jules" /usr/local/bin/jules
```

If you prefer a user-local location:

```bash
mkdir -p "$HOME/.local/bin"
ln -sf "$(pwd)/bin/jules" "$HOME/.local/bin/jules"
```

Then ensure `~/.local/bin` is in your shell PATH (for `zsh`, add to `~/.zshrc`):

```bash
export PATH="$HOME/.local/bin:$PATH"
```

## Run

```bash
jules
```

Useful flags:

```bash
jules --help
jules --provider openrouter
jules --model qwen/qwen3-coder-flash
jules --list-models
```

## Development

```bash
bundle exec rake test
bundle exec rubocop
bundle exec rake ci
```
