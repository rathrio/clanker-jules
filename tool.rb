# frozen_string_literal: true

require 'tempfile'
require 'shellwords'

module Tool
  JSON_TYPES = {
    String => 'string',
    Integer => 'number',
    Float => 'number'
  }.freeze

  # rubocop:disable Metrics/AbcSize
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
  # rubocop:enable Metrics/AbcSize

  def self.as_gemini_param_properties(params)
    params.to_h do |param|
      [
        param.fetch(:name),
        { type: JSON_TYPES.fetch(param.fetch(:type)), description: param['description'] }
      ]
    end
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
    begin
      find(name).new.call(args)
    rescue StandardError => e
      "Error executing tool '#{name}': #{e.class} - #{e.message}"
    end
  end

  def as_json_type(type)
    JSON_TYPES.fetch(type)
  end
end

Dir[File.join(__dir__, 'tools', '*.rb')].each { |file| require file }
