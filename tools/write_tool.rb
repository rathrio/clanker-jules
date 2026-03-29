# frozen_string_literal: true

class WriteTool
  include Tool

  def self.description
    'Write content to a file at the given path. Creates the file if it does not exist, or overwrites it if it does.'
  end

  def self.render_execution(args)
    "Writing to file: #{args['path']}"
  end

  param name: 'path', type: String, description: 'The path to the file to write'
  param name: 'content', type: String, description: 'The content to write to the file'
  def call(params)
    File.write(File.expand_path(params.fetch('path')), params.fetch('content'))
    params.fetch('path')
  end
end
