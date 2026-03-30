# frozen_string_literal: true

module Jules
  class Message
    attr_reader :role, :parts

    # @param role [String] user, model, or tool
    # @param parts [Array<Hash>] provider-neutral parts:
    #   { text: "..." }
    #   { function_call: { name:, args:, id: } }
    #   { function_response: { name:, result:, id: } }
    #   { _raw_gemini: { ... } } (for thinking parts, passed through as-is)
    def initialize(role, parts)
      @role = role
      @parts = parts
    end

    def self.format_history(history, format:)
      case format
      when :gemini
        history.map(&:as_gemini)
      when :openai
        history.flat_map(&:as_openai)
      else
        raise "Unknown message format: #{format}"
      end
    end

    def as_gemini
      gemini_parts = @parts.map do |part|
        if part[:_raw_gemini]
          part[:_raw_gemini]
        elsif part[:text]
          { text: part[:text] }
        elsif (fc = part[:function_call])
          { functionCall: { name: fc[:name], args: fc[:args] } }
        elsif (fr = part[:function_response])
          { functionResponse: { name: fr[:name], response: { result: fr[:result] } } }
        end
      end.compact

      { role: @role == 'tool' ? 'user' : @role, parts: gemini_parts }
    end

    def as_openai
      if @role == 'tool'
        return @parts.map do |part|
          fr = part[:function_response]
          { role: 'tool', tool_call_id: fr[:id], content: fr[:result].to_s }
        end
      end

      function_calls = @parts.select { |p| p[:function_call] }
      if function_calls.any?
        return [{
          role: 'assistant',
          tool_calls: function_calls.map do |p|
            fc = p[:function_call]
            { id: fc[:id], type: 'function', function: { name: fc[:name], arguments: fc[:args].to_json } }
          end
        }]
      end

      openai_role = @role == 'model' ? 'assistant' : @role
      [{ role: openai_role, content: @parts.filter_map { |p| p[:text] }.join }]
    end
  end
end
