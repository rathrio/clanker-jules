# frozen_string_literal: true

class EditTool
  include Tool

  def self.description
    <<~DESC.chomp
      Make a targeted edit to a file by replacing one unique string with another. Shows a diff of the change.

      Use this tool when you:
      - Need to change a specific, small part of a file (rename a variable, fix a line, update a value)
      - The search string must appear exactly once in the file — include enough surrounding context to be unique

      Use patch instead for multi-hunk changes across a file. Use write for creating new files or full rewrites.
    DESC
  end

  def self.render_execution(args)
    "Editing file: #{args['path']}"
  end

  param name: 'path', type: String, description: 'The path to the file to edit'
  param name: 'search', type: String, description: 'The exact string to search for in the file. Must be unique.'
  param name: 'replace', type: String, description: 'The string to replace the search string with'
  def call(params)
    path = params.fetch('path')
    search = params.fetch('search')
    replace = params.fetch('replace')

    return 'Error: File does not exist.' unless File.exist?(path)

    content = File.read(path)

    return 'Error: Search string not found in file. Ensure exact whitespace matching.' unless content.include?(search)

    count = content.scan(search).size
    return "Error: Search string found #{count} times. Provide more context to make it unique." if count > 1

    new_content = content.sub(search, replace)

    display_diff(path, content, new_content)

    File.write(path, new_content)
    "Edited #{path}"
  end

  def display_diff(path, old_content, new_content)
    old_file = Tempfile.new('old')
    new_file = Tempfile.new('new')
    old_file.write(old_content)
    new_file.write(new_content)
    old_file.close
    new_file.close

    puts "\n"
    diff_command = [
      'diff -u',
      "-L #{path.shellescape}",
      "-L #{path.shellescape}",
      old_file.path.shellescape,
      new_file.path.shellescape
    ].join(' ')
    diff = `#{diff_command}`
    diff.each_line do |line|
      if line.start_with?('+++') || line.start_with?('---')
        print "\e[1m#{line}\e[0m"
      elsif line.start_with?('+')
        print "\e[32m#{line}\e[0m"
      elsif line.start_with?('-')
        print "\e[31m#{line}\e[0m"
      elsif line.start_with?('@@')
        print "\e[36m#{line}\e[0m"
      else
        print line
      end
    end
    puts "\n"

    old_file.unlink
    new_file.unlink
  end
  # rubocop:enable Metrics/AbcSize
end
