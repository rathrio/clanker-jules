# frozen_string_literal: true

module Jules
  class ReadTool
    include Tool

    def self.description
      <<~DESC.chomp
        Read the contents of a file. Use start_line/end_line to read a specific range of a large file.

        Use this tool when you:
        - Need to understand existing code before modifying it
        - Want to see the full context around a search/find_code result
        - Need to verify file contents before writing or editing
      DESC
    end

    def self.execution_summary(args)
      range = if args['start_line'] && args['end_line']
                " (lines #{args['start_line']}-#{args['end_line']})"
              elsif args['start_line']
                " (from line #{args['start_line']})"
              end
      { detail: "#{args['path']}#{range}" }
    end

    param name: 'path', type: String, description: 'The path to the file to read'
    param name: 'start_line', type: Integer, description: 'The line number to start reading from', optional: true
    param name: 'end_line', type: Integer, description: 'The line number to stop reading at', optional: true

    def call(params)
      path = params.fetch('path')
      start_line = params['start_line']
      end_line = params['end_line']

      return File.read(path) unless start_line || end_line

      lines = File.readlines(path)
      start_index = start_line ? [start_line.to_i - 1, 0].max : 0
      end_index = end_line ? [end_line.to_i - 1, lines.length - 1].min : lines.length - 1

      lines[start_index..end_index].join
    end
  end
end
