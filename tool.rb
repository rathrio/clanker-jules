module Tool
  JSON_TYPES = {
    String => 'string',
    Integer => 'number',
    Float => 'number',
  }

  def self.included(klass)
    klass.define_singleton_method(:param) do |param|
      @params ||= []
      @params << param
    end

    klass.define_singleton_method(:params) do
      @params
    end

    klass.define_singleton_method(:tool_name) do
      klass.to_s.sub(/Tool$/, '').downcase
    end

    klass.define_singleton_method(:as_gemini_declaration) do
      {
        name: klass.tool_name,
        description: klass.description,
        parameters: {
          type: 'object',
          properties: Tool.as_gemini_param_properties(klass.params),
          required: Tool.infer_required_params(klass.params)
        }
      }
    end

    klass.define_singleton_method(:render_execution) do |args|
      "Executing #{klass.tool_name} with args: #{args.to_json}"
    end

    @known_tools ||= {}
    @known_tools[klass.tool_name] = klass
  end

  def self.as_gemini_param_properties(params)
    params.map do |param|
      [
        param.fetch(:name),
        { type: JSON_TYPES.fetch(param.fetch(:type)), description: param['description'] }
      ]
    end.to_h
  end

  def self.infer_required_params(params)
    params
      .reject { |param| param[:optional] }
      .map { |param| param.fetch(:name) }
  end

  def self.all
    @known_tools.values
  end

  def self.all_gemini_declarations
    all.map(&:as_gemini_declaration)
  end

  def self.find(name)
    @known_tools.fetch(name)
  end

  def self.call(name, args)
    find(name).new.call(args)
  end

  def as_json_type(type)
    JSON_TYPES.fetch(type)
  end
end

class BashTool
  include Tool

  def self.description
    'Execute a bash command and return its output'
  end

  def self.render_execution(args)
    "Running: `#{args['command']}`"
  end

  param name: 'command', type: String, description: 'The bash command to execute'
  def call(params)
    `#{params.fetch('command')}`
  end
end

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

class WriteTool
  include Tool

  def self.description
    'Write content to a file at the given path. Creates the file if it does not exist, or overwrites it if it does.'
  end

  def self.render_execution(args)
    "Writing to file: #{args['path']}"
  end

  param name: 'path', type: String, description: 'The path to the file to write'
  param name: 'content', type: String, description: 'The content to write to the file'
  def call(params)
    File.write(params.fetch('path'), params.fetch('content'))
    params.fetch('path')
  end
end

class EditTool
  include Tool

  def self.description
    'Edit a file by replacing an exact search string with a new string. Provide enough context in the search string to ensure a unique match.'
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

    return "Error: File does not exist." unless File.exist?(path)

    content = File.read(path)

    unless content.include?(search)
      return "Error: Search string not found in file. Ensure exact whitespace matching."
    end

    count = content.scan(search).size
    if count > 1
      return "Error: Search string found #{count} times. Provide more context to make it unique."
    end

    File.write(path, content.sub(search, replace))
    "Successfully edited #{path}"
  end
end
