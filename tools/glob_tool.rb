# frozen_string_literal: true

require 'open3'
require_relative 'rg'

class GlobTool
  include Tool
  include Rg

  def self.description
    'Find files by glob pattern (for example: **/*.rb or **/*_test.rb).'
  end

  def self.render_execution(args)
    pattern = args['pattern']
    base_path = args['path'] || '.'
    "Finding files with pattern: #{pattern} (in #{base_path})"
  end

  param name: 'pattern', type: String, description: 'Glob pattern to match files (for example: **/*.rb).'
  param name: 'path', type: String, description: 'Base directory for the glob search.', optional: true
  param name: 'max_results', type: Integer, description: 'Maximum number of matched files to return (default: 500).', optional: true
  param name: 'exclude_glob', type: String, description: 'Optional comma-separated file globs to exclude from results.', optional: true
  param name: 'include_dotfiles', type: String, description: 'Set to true to include dotfiles (default: false).', optional: true

  def call(params)
    pattern = params.fetch('pattern').to_s
    base_path = File.expand_path(params['path'] || '.')
    max_results = (params['max_results'] || 500).to_i
    exclude_globs = parse_globs(params['exclude_glob'])
    include_dotfiles = truthy?(params['include_dotfiles'])

    return "Error: path not found: #{base_path}" unless Dir.exist?(base_path)
    return 'Error: pattern cannot be empty.' if pattern.strip.empty?

    stdout, stderr, status = Open3.capture3(*build_command(pattern, base_path, exclude_globs, include_dotfiles))

    return "No files matched pattern '#{pattern}'." if status.exitstatus == 1
    return "Error: rg failed - #{stderr.strip}" unless status.success?

    matches = stdout.lines(chomp: true)
                    .map { |path| relative_to_base(path, base_path) }
                    .sort
    return "No files matched pattern '#{pattern}'." if matches.empty?

    displayed = matches.first(max_results)
    output = displayed.join("\n")

    if matches.length > max_results
      "#{output}\n...truncated at #{max_results} files."
    else
      output
    end
  end

  private

  def build_command(pattern, base_path, exclude_globs, include_dotfiles)
    command = ['rg', '--files']
    command << '--hidden' if include_dotfiles
    command.push('--glob', pattern)
    add_exclude_globs(command, exclude_globs)
    command << base_path
    command
  end

  def truthy?(value)
    value.to_s.strip.downcase == 'true'
  end
end
