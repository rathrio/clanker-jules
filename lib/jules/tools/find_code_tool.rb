# frozen_string_literal: true

require 'json'
require 'open3'
require_relative 'rg'

module Jules
  class FindCodeTool
    include Tool
    include Rg

    DEFAULT_EXCLUDES = %w[.git node_modules .svn .hg].freeze
    MAX_MATCH_LINES = 10

    # Languages where class method names use property_identifier instead of identifier
    PROPERTY_ID_LANGUAGES = %w[javascript typescript tsx].freeze

    # Maps language -> kind category -> tree-sitter node kinds
    DEFINITION_KINDS = {
      'ruby' => %w[method singleton_method class module],
      'javascript' => %w[function_declaration class_declaration method_definition],
      'typescript' => %w[function_declaration class_declaration method_definition],
      'tsx' => %w[function_declaration class_declaration method_definition],
      'python' => %w[function_definition class_definition],
      'java' => %w[method_declaration class_declaration interface_declaration],
      'go' => %w[function_declaration method_declaration],
      'rust' => %w[function_item impl_item struct_item enum_item]
    }.freeze

    CALL_KINDS = {
      'ruby' => %w[call],
      'javascript' => %w[call_expression new_expression],
      'typescript' => %w[call_expression new_expression],
      'tsx' => %w[call_expression new_expression],
      'python' => %w[call],
      'java' => %w[method_invocation object_creation_expression],
      'go' => %w[call_expression],
      'rust' => %w[call_expression macro_invocation]
    }.freeze

    def self.description
      <<~DESC.chomp
        Find code by structure. Two modes:

        ## Mode 1: Search by name (simple — use this when you can)
        Set `name` to find definitions or calls of a function/method/class by name. Requires `lang`.
          name: "perform", lang: "ruby"                        → finds method definitions named "perform"
          name: "perform", lang: "ruby", kind: "call"          → finds calls to "perform"
          name: "Worker", lang: "python", kind: "definition"   → finds class/function definitions named "Worker"

        ## Mode 2: Search by pattern (powerful — use when you need structural matching)
        Set `pattern` to write a code snippet of what you're looking for, using $VAR as wildcards \
        and $$$ for multiple statements. Understands syntax, so it won't match inside strings or comments.

        IMPORTANT: Patterns must use the actual syntax of the target language. When searching multiple \
        languages, make separate calls with `lang` set and a pattern written in that language's syntax.

        Pattern syntax (reference: https://ast-grep.github.io/guide/pattern-syntax.html):
          $VAR   — matches any single expression (use any name: $NAME, $ARGS, $X)
          $$$    — matches any number of statements (use inside method/block bodies)

        Examples by language:
          Ruby:
            def $NAME $$$ end                       — method definitions (no parens)
            def $NAME($ARGS) $$$ end                — method definitions (with args)
            class $NAME < $PARENT $$$ end           — class with inheritance
            $OBJ.each do |$X| $$$ end               — .each blocks

          JavaScript/TypeScript:
            function $NAME($ARGS) { $$$ }           — function declarations
            const $NAME = ($ARGS) => { $$$ }        — arrow functions
            const $NAME = ($ARGS) => $EXPR          — single-expression arrows
            class $NAME extends $PARENT { $$$ }     — class with inheritance
            $OBJ.map($FN)                           — method calls

          Python:
            def $NAME($ARGS): $$$                   — function definitions
            class $NAME($PARENT): $$$               — class with inheritance
            for $X in $ITER: $$$                    — for loops

          Java:
            public $RET $NAME($ARGS) { $$$ }        — public method definitions
            class $NAME extends $PARENT { $$$ }     — class with inheritance
            for ($INIT; $COND; $STEP) { $$$ }       — for loops
            if ($COND) { $$$ }                      — if blocks

        Use search instead when you:
        - Know the exact string (a variable name, error message, import path)
        - Want simple text/regex matching without structural awareness
      DESC
    end

    def self.execution_summary(args)
      base_path = args['path'] || '.'
      target = args['name'] || args['pattern']
      { detail: "#{target} in #{base_path}" }
    end

    param name: 'pattern',
          type: String,
          description: 'A code snippet to match, written in the target language\'s syntax. Use $VAR as a ' \
                       'wildcard for any single expression and $$$ for multiple statements. ' \
                       'Ruby example: "def $NAME($ARGS) $$$ end", JS example: "function $NAME($ARGS) { $$$ }"',
          optional: true
    param name: 'name',
          type: String,
          description: 'Find definitions or calls by name (e.g. "perform", "MyClass"). Simpler than pattern — ' \
                       'just provide the identifier name. Requires lang to be set.',
          optional: true
    param name: 'kind',
          type: String,
          description: 'Used with name. What to find: "definition" (default) finds function/method/class ' \
                       'definitions, "call" finds function/method calls, "all" finds any reference.',
          optional: true
    param name: 'path', type: String, description: 'Directory or file path to search within.', optional: true
    param name: 'lang', type: String, description: 'Language to parse as (e.g. ruby, typescript, python). Required when using name.', optional: true
    param name: 'max_results', type: Integer, description: 'Maximum number of matches to return (default: 200).', optional: true
    param name: 'include_glob', type: String, description: 'Comma-separated file globs to include.', optional: true
    param name: 'exclude_glob', type: String, description: 'Comma-separated file globs to exclude.', optional: true

    def call(params)
      name = params['name']&.to_s&.strip
      pattern = params['pattern']&.to_s&.strip
      base_path = File.expand_path(params['path'] || '.')
      max_results = (params['max_results'] || 200).to_i
      lang = params['lang']
      kind = params['kind']&.to_s&.strip || 'definition'
      include_globs = parse_globs(params['include_glob'])
      exclude_globs = parse_globs(params['exclude_glob'])

      return 'Error: provide either name or pattern.' if blank?(name) && blank?(pattern)
      return "Error: path not found: #{base_path}" unless File.exist?(base_path)

      if blank?(name)
        search_by_pattern(pattern, lang, base_path, max_results, include_globs, exclude_globs)
      else
        return 'Error: lang is required when using name.' if blank?(lang)

        search_by_name(name, lang, kind, base_path, max_results, include_globs, exclude_globs)
      end
    rescue Errno::ENOENT
      'Error: ast-grep is not installed or not in PATH.'
    end

    private

    def search_by_name(name, lang, kind, base_path, max_results, include_globs, exclude_globs) # rubocop:disable Metrics/ParameterLists
      node_kinds = node_kinds_for(lang, kind)
      return "Error: unsupported language '#{lang}' for name search." unless node_kinds

      rule = build_name_rule(name, lang, node_kinds)
      command = ['ast-grep', 'scan', '--inline-rules', rule, '--json=stream']
      append_globs(command, include_globs, exclude_globs)
      command << base_path

      run_and_format(command, "name '#{name}'", base_path, max_results)
    end

    def search_by_pattern(pattern, lang, base_path, max_results, include_globs, exclude_globs) # rubocop:disable Metrics/ParameterLists
      command = ['ast-grep', 'run', '--pattern', pattern, '--json=stream']
      command.push('--lang', lang) unless blank?(lang)
      append_globs(command, include_globs, exclude_globs)
      command << base_path

      run_and_format(command, "pattern '#{pattern}'", base_path, max_results)
    end

    def run_and_format(command, description, base_path, max_results)
      stdout, stderr, status = Open3.capture3(*command)

      return "No matches found for #{description}." if status.exitstatus == 1
      return "Error: ast-grep failed - #{stderr.strip}" unless status.success?

      lines = stdout.lines(chomp: true).reject(&:empty?)
      return "No matches found for #{description}." if lines.empty?

      formatted = lines.first(max_results).map { |line| format_result_line(line, base_path) }
      output = formatted.join("\n\n")

      if lines.size > max_results
        "#{output}\n\n...truncated at #{max_results} matches. Narrow your search for more precise results."
      else
        output
      end
    end

    def node_kinds_for(lang, kind)
      lang = lang.downcase
      case kind
      when 'definition' then DEFINITION_KINDS[lang]
      when 'call' then CALL_KINDS[lang]
      when 'all'
        defs = DEFINITION_KINDS[lang]
        calls = CALL_KINDS[lang]
        return nil unless defs || calls

        ((defs || []) + (calls || [])).uniq
      end
    end

    def build_name_rule(name, lang, node_kinds)
      kinds_yaml = node_kinds.map { |k| "    - kind: #{k}" }.join("\n")
      escaped_name = Regexp.escape(name)
      has_rule = if PROPERTY_ID_LANGUAGES.include?(lang.downcase)
                   "    any:\n      - kind: identifier\n      - kind: property_identifier\n    regex: \"^#{escaped_name}$\""
                 else
                   "    kind: identifier\n    regex: \"^#{escaped_name}$\""
                 end

      "id: find\nlanguage: #{lang}\nrule:\n  any:\n#{kinds_yaml}\n  has:\n#{has_rule}\n"
    end

    def append_globs(command, include_globs, exclude_globs)
      include_globs.each { |glob| command.push('--globs', glob) }
      all_excludes(exclude_globs).each { |glob| command.push('--globs', "!#{glob.delete_prefix('!')}") }
    end

    def all_excludes(exclude_globs)
      DEFAULT_EXCLUDES.map { |name| "**/#{name}/**" } + exclude_globs
    end

    def blank?(value)
      value.nil? || value.empty?
    end

    def format_result_line(line, base_path)
      data = JSON.parse(line)
      file = data['file'].to_s
      display = File.file?(base_path) ? file : relative_to_base(file, base_path)
      line_number = data.dig('range', 'start', 'line') || '?'

      header = "#{display}:#{line_number}"
      parts = [header]

      vars = format_meta_variables(data['metaVariables'])
      parts << "  vars: #{vars}" unless vars.empty?

      text = data['text'].to_s
      match_lines = text.lines
      if match_lines.length > MAX_MATCH_LINES
        parts << indent_match(match_lines.first(MAX_MATCH_LINES).join)
        parts << "  ... (#{match_lines.length - MAX_MATCH_LINES} more lines)"
      else
        parts << indent_match(text)
      end

      parts.join("\n")
    rescue JSON::ParserError
      line
    end

    def format_meta_variables(meta)
      return '' unless meta.is_a?(Hash)

      entries = []

      (meta['single'] || {}).each do |name, node|
        entries << "$#{name}=#{node['text']}" if node.is_a?(Hash)
      end

      (meta['multi'] || {}).each do |name, nodes|
        next unless nodes.is_a?(Array)

        texts = nodes.filter_map { |n| n['text'] if n.is_a?(Hash) && n['text'] != ',' }
        entries << "$$$#{name}=[#{texts.join(', ')}]"
      end

      entries.join(', ')
    end

    def indent_match(text)
      text.lines.map { |l| "  #{l}" }.join.chomp
    end
  end
end
