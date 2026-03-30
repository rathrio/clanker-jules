# frozen_string_literal: true

class BashTool
  include Tool

  def self.description
    <<~DESC.chomp
      Run a shell command and return its output.

      Use this tool when you:
      - Need to run tests, linters, or build commands: bundle exec rake test
      - Need git operations: git status, git diff, git log
      - Need to install dependencies or run project scripts
      - Need system information not available through other tools

      Prefer other tools for file operations: use read, edit, write, search, glob, find_code instead of \
      cat, sed, grep, find, etc.
    DESC
  end

  def self.render_execution(args)
    "Running: `#{args['command']}`"
  end

  param name: 'command', type: String, description: 'The bash command to execute'
  def call(params)
    `#{params.fetch('command')}`
  end
end
