# frozen_string_literal: true

require 'open3'

module Jules
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
      "BASH: #{args['command']}"
    end

    param name: 'command', type: String, description: 'The bash command to execute'
    def call(params)
      output, status = Open3.capture2e(params.fetch('command'))
      return output if status.success?

      raise "Command failed with exit status #{status.exitstatus}: #{params.fetch('command')}"
    end
  end
end
