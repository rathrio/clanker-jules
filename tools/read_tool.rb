# frozen_string_literal: true

class ReadTool
  include Tool

  def self.description
    'Read the contents of a file at the given path'
  end

  def self.render_execution(args)
    "Reading file: #{args['path']}"
  end

  param name: 'path', type: String, description: 'The path to the file to read'
  def call(params)
    File.read(params.fetch('path'))
  end
end
