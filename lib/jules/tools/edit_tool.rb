# frozen_string_literal: true

module Jules
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

    def self.execution_summary(args)
      { detail: args['path'] }
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
      diff = display_diff(path, content, new_content)

      File.write(path, new_content)

      return "Edited #{path}" if diff.to_s.strip.empty?

      "#{diff}\nEdited #{path}"
    end

    def display_diff(path, old_content, new_content)
      Jules::Diff.render_unified_diff(
        old_content: old_content,
        new_content: new_content,
        old_label: path,
        new_label: path
      )
    end
    # rubocop:enable Metrics/AbcSize
  end
end
