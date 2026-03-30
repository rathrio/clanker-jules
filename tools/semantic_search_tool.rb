# frozen_string_literal: true

require 'json'
require 'open3'
require_relative 'rg'

class SemanticSearchTool
  include Tool
  include Rg

  DEFAULT_EXCLUDES = %w[.git node_modules .svn .hg].freeze

  def self.description
    'Search code structurally using ast-grep (Tree-sitter), returning matches as file:line:text. Prefer this tool over search or grep/rg if semantic precision is required.'
  end

  def self.render_execution(args)
    pattern = args['pattern']
    base_path = args['path'] || '.'
    "Semantic search for pattern #{pattern.inspect} in: #{base_path}"
  end

  param name: 'pattern', type: String, description: 'AST pattern to match (ast-grep syntax).'
  param name: 'path', type: String, description: 'Directory or file path to search within.', optional: true
  param name: 'lang', type: String, description: 'Optional language override (for example: ruby, typescript).', optional: true
  param name: 'strictness', type: String, description: 'Optional pattern strictness (cst, smart, ast, relaxed, signature).', optional: true
  param name: 'max_results', type: Integer, description: 'Maximum number of matches to return (default: 200).', optional: true
  param name: 'include_glob', type: String, description: 'Optional comma-separated file globs to include.', optional: true
  param name: 'exclude_glob', type: String, description: 'Optional comma-separated file globs to exclude.', optional: true

  def call(params)
    pattern = params.fetch('pattern').to_s
    base_path = File.expand_path(params['path'] || '.')
    max_results = (params['max_results'] || 200).to_i
    lang = params['lang']
    strictness = params['strictness']
    include_globs = parse_globs(params['include_glob'])
    exclude_globs = parse_globs(params['exclude_glob'])

    return 'Error: pattern cannot be empty.' if pattern.strip.empty?
    return "Error: path not found: #{base_path}" unless File.exist?(base_path)

    options = {
      lang: lang,
      strictness: strictness,
      include_globs: include_globs,
      exclude_globs: exclude_globs
    }

    stdout, stderr, status = Open3.capture3(*build_command(pattern, base_path, options))

    return "No matches found for pattern '#{pattern}'." if status.exitstatus == 1
    return "Error: ast-grep failed - #{stderr.strip}" unless status.success?

    lines = stdout.lines(chomp: true).reject(&:empty?)
    return "No matches found for pattern '#{pattern}'." if lines.empty?

    formatted = lines.first(max_results).map { |line| format_result_line(line, base_path) }
    output = formatted.join("\n")

    if lines.size > max_results
      "#{output}\n...truncated at #{max_results} matches. Narrow your pattern for more precise results."
    else
      output
    end
  rescue Errno::ENOENT
    'Error: ast-grep is not installed or not in PATH.'
  end

  private

  def build_command(pattern, base_path, options)
    command = ['ast-grep', 'run', '--pattern', pattern, '--json=stream']
    command.push('--lang', options[:lang]) if present?(options[:lang])
    command.push('--strictness', options[:strictness]) if present?(options[:strictness])

    options[:include_globs].each { |glob| command.push('--globs', glob) }
    add_ast_grep_exclude_globs(command, all_excludes(options[:exclude_globs]))

    command << base_path
    command
  end

  def add_ast_grep_exclude_globs(command, globs)
    globs.each do |glob|
      command.push('--globs', "!#{glob.delete_prefix('!')}")
    end
    command
  end

  def all_excludes(exclude_globs)
    DEFAULT_EXCLUDES.map { |name| "**/#{name}/**" } + exclude_globs
  end

  def format_result_line(line, base_path)
    data = JSON.parse(line)
    file = data['file'].to_s
    display = File.file?(base_path) ? file : relative_to_base(file, base_path)
    line_number = data.dig('range', 'start', 'line') || '?'

    text = data['text'].to_s
    first_line = text.lines.first.to_s.chomp
    suffix = text.lines.count > 1 ? ' …' : ''

    "#{display}:#{line_number}:#{first_line}#{suffix}"
  rescue JSON::ParserError
    line
  end

  def present?(value)
    value && !value.strip.empty?
  end
end
