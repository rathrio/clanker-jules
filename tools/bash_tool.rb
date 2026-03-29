# frozen_string_literal: true

class BashTool
  include Tool

  def self.description
    'Execute a bash command and return its output'
  end

  def self.render_execution(args)
    "Running: `#{args['command']}`"
  end

  param name: 'command', type: String, description: 'The bash command to execute'
  def call(params)
    `#{params.fetch('command')}`
  end
end
