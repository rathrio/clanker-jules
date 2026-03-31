# frozen_string_literal: true

require 'tempfile'
require 'shellwords'

module Jules
  module Tool
    JSON_TYPES = {
      String => 'string',
      Integer => 'number',
      Float => 'number'
    }.freeze

    module ClassMethods
      def render_execution(args)
        "#{tool_name.upcase}: #{args.to_json}"
      end
    end

    def self.included(klass)
      klass.extend(ClassMethods)

      klass.define_singleton_method(:param) do |param|
        @params ||= []
        @params << param
      end

      klass.define_singleton_method(:params) do
        @params
      end

      klass.define_singleton_method(:tool_name) do
        klass.to_s.split('::').last.sub(/Tool$/, '').downcase
      end

      klass.define_singleton_method(:as_gemini_declaration) do
        {
          name: klass.tool_name,
          description: klass.description,
          parameters: {
            type: 'object',
            properties: Tool.as_json_schema_properties(klass.params),
            required: Tool.infer_required_params(klass.params)
          }
        }
      end

      klass.define_singleton_method(:as_openai_declaration) do
        {
          type: 'function',
          function: {
            name: klass.tool_name,
            description: klass.description,
            parameters: {
              type: 'object',
              properties: Tool.as_json_schema_properties(klass.params),
              required: Tool.infer_required_params(klass.params)
            }
          }
        }
      end

      @known_tools ||= {}
      @known_tools[klass.tool_name] = klass
    end
    # rubocop:enable Metrics/AbcSize

    def self.as_json_schema_properties(params)
      params.to_h do |param|
        [
          param.fetch(:name),
          { type: JSON_TYPES.fetch(param.fetch(:type)), description: param.fetch(:description) }
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

    def self.declarations(format:)
      case format
      when :gemini
        all.map(&:as_gemini_declaration)
      when :openai
        all.map(&:as_openai_declaration)
      else
        raise "Unknown tool format: #{format}"
      end
    end

    def self.find(name)
      @known_tools.fetch(name) do
        available_tools = @known_tools.keys.sort.join(', ')
        raise KeyError, "Unknown tool '#{name}'. Available tools: #{available_tools}"
      end
    end

    def self.call(name, args)
      find(name).new.call(args)
    rescue StandardError => e
      "Error executing tool '#{name}': #{e.class} - #{e.message}"
    end

    def as_json_type(type)
      JSON_TYPES.fetch(type)
    end
  end
end

Dir[File.join(__dir__, 'tools', '*.rb')].each { |file| require file }
