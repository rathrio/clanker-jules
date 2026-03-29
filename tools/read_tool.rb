# frozen_string_literal: true

class ReadTool
  include Tool

  def self.description
    'Read the contents of a file at the given path. Can optionally read a specific range of lines.'
  end

  def self.render_execution(args)
    if args['start_line'] && args['end_line']
      "Reading lines #{args['start_line']}-#{args['end_line']} from file: #{args['path']}"
    elsif args['start_line']
      "Reading from line #{args['start_line']} to the end of file: #{args['path']}"
    else
      "Reading file: #{args['path']}"
    end
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
