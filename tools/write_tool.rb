# frozen_string_literal: true

class WriteTool
  include Tool

  def self.description
    <<~DESC.chomp
      Create a new file or completely overwrite an existing one.

      Use this tool when you:
      - Are creating a brand new file
      - Need to rewrite a file entirely (the whole content changes)

      Use edit for small, targeted changes. Use patch for applying diffs to existing files.
    DESC
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
