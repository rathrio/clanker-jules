# frozen_string_literal: true

require 'open3'
require_relative 'rg'

module Jules
  class SearchTool
    include Tool
    include Rg

    DEFAULT_EXCLUDES = %w[.git node_modules .svn .hg].freeze

    def self.description
      <<~DESC.chomp
        Search for exact text or patterns across files. Returns matching lines as file:line:content.

        Use this tool when you:
        - Know the exact string you're looking for (a variable name, error message, string literal)
        - Want to find all usages of a specific identifier: search for "current_user"
        - Need regex matching: use_regex=true with "def (create|update)"
        - Want to search within specific file types: include_glob="**/*.rb"

        Use find_code instead when you need structural matching (e.g. "find all method definitions" or \
        "find calls to foo with two arguments") — search matches raw text, find_code understands code structure.
      DESC
    end

    def self.render_execution(args)
      query = args['query']
      base_path = args['path'] || '.'
      "SEARCH: \"#{query}\" in #{base_path}"
    end

    param name: 'query', type: String, description: 'The text to search for.'
    param name: 'path', type: String, description: 'Directory or file path to search within.', optional: true
    param name: 'max_results', type: Integer, description: 'Maximum number of matching lines to return (default: 200).', optional: true
    param name: 'use_regex', type: String, description: 'Set to true to treat query as a regular expression.', optional: true
    param name: 'ignore_case', type: String, description: 'Set to true for case-insensitive matching.', optional: true
    param name: 'include_glob', type: String, description: 'Optional comma-separated file globs to include (for example: **/*.rb,**/*.md).', optional: true
    param name: 'exclude_glob', type: String, description: 'Optional comma-separated file globs to exclude.', optional: true

    def call(params)
      query = params.fetch('query').to_s
      base_path = File.expand_path(params['path'] || '.')
      max_results = (params['max_results'] || 200).to_i
      use_regex = self.class.truthy?(params['use_regex'])
      ignore_case = self.class.truthy?(params['ignore_case'])
      include_globs = parse_globs(params['include_glob'])
      exclude_globs = parse_globs(params['exclude_glob'])

      return 'Error: query cannot be empty.' if query.strip.empty?
      return "Error: path not found: #{base_path}" unless File.exist?(base_path)

      regex_error = validate_regex(query, ignore_case) if use_regex
      return regex_error if regex_error

      options = {
        use_regex: use_regex,
        ignore_case: ignore_case,
        include_globs: include_globs,
        exclude_globs: exclude_globs
      }

      stdout, stderr, status = Open3.capture3(*build_command(query, base_path, options))

      return "No matches found for '#{query}'." if status.exitstatus == 1
      return "Error: rg failed - #{stderr.strip}" unless status.success?

      lines = stdout.lines(chomp: true).first(max_results)
      return "No matches found for '#{query}'." if lines.empty?

      output = lines.map { |line| format_vimgrep_line(line, base_path) }.join("\n")
      if stdout.lines.size > max_results
        "#{output}\n...truncated at #{max_results} matches. Narrow your query for more precise results."
      else
        output
      end
    end

    def self.truthy?(value)
      value.to_s.strip.downcase == 'true'
    end

    private

    def build_command(query, base_path, options)
      command = base_command(options[:use_regex], options[:ignore_case])

      options[:include_globs].each { |glob| command.push('--glob', glob) }
      add_exclude_globs(command, all_excludes(options[:exclude_globs]))

      command << query
      command << base_path
      command
    end

    def base_command(use_regex, ignore_case)
      command = ['rg', '--vimgrep', '--no-heading', '--color', 'never', '--hidden']
      command << '-F' unless use_regex
      command << '-i' if ignore_case
      command
    end

    def all_excludes(exclude_globs)
      DEFAULT_EXCLUDES.map { |name| "!**/#{name}/**" } + exclude_globs
    end

    def validate_regex(query, ignore_case)
      flags = ignore_case ? Regexp::IGNORECASE : 0
      Regexp.new(query, flags)
      nil
    rescue RegexpError => e
      "Error: invalid regex - #{e.message}"
    end

    def format_vimgrep_line(line, base_path)
      file, line_number, _column, content = line.split(':', 4)
      display = File.file?(base_path) ? file : relative_to_base(file, base_path)
      "#{display}:#{line_number}:#{content}"
    end
  end
end
