# frozen_string_literal: true

module Jules
  class Chat
    def initialize(provider:, tools:, system_prompt:, chats_dir:, terminal: Jules::Terminal)
      @provider = provider
      @tools = tools
      @system_prompt = system_prompt
      @chats_dir = chats_dir
      @terminal = terminal
      @messages = []
      @session_started_at = nil
    end

    def run
      install_exit_handler

      loop do
        input = @terminal.read_input
        next if input.empty?

        next if handle_slash_command?(input)

        ensure_session_started
        @messages << Jules::Message.new('user', [{ text: input }])

        process_model_turn
      rescue Interrupt
        @terminal.print_interrupt
      end
    end

    private

    def install_exit_handler
      at_exit { flush_chat_log }
    end

    def ensure_session_started
      return if @session_started_at

      @session_started_at = Time.now.strftime('%Y-%m-%dT%H%M%S%Z')
    end

    def process_model_turn
      loop do
        response = @terminal.with_spinner(leading_newline: true) do
          @provider.generate_content(@messages, @tools, system_prompt: @system_prompt)
        end

        parsed_response = @provider.parse_response(response)
        extra_parts = parsed_response[:extra_parts] || []

        case parsed_response[:type]
        when :message
          @messages << Jules::Message.new('model', extra_parts + [{ text: parsed_response[:data] }])
          @terminal.print_assistant(parsed_response[:data])
          break
        when :tool_calls
          append_model_tool_calls(parsed_response[:data], extra_parts)
          append_tool_results(parsed_response[:data])
        when :error
          @terminal.print_error(parsed_response[:data], raw: response.inspect)
          break
        end
      end
    end

    def append_model_tool_calls(calls, extra_parts)
      model_parts = extra_parts + calls.map do |call|
        { function_call: { name: call[:name], args: call[:args], id: call[:id] } }
      end
      @messages << Jules::Message.new('model', model_parts)
    end

    def append_tool_results(calls)
      tool_results = calls.map do |call|
        tool_class = begin
          Jules::Tool.find(call[:name])
        rescue KeyError
          nil
        end

        execution = if tool_class
                      tool_class.render_execution(call[:args])
                    else
                      "UNKNOWN TOOL: #{call[:name]}"
                    end
        @terminal.print_tool_execution(execution)

        result = Jules::Tool.call(call[:name], call[:args])
        @terminal.print_tool_preview(call[:name], result)
        { function_response: { name: call[:name], result: result, id: call[:id] } }
      end

      @messages << Jules::Message.new('tool', tool_results)
    end

    def handle_slash_command?(input)
      case @terminal.parse_slash_command(input)
      when :clear
        @messages.clear
        @session_started_at = nil
        @terminal.print_scene_cut
        true
      when Array
        handle_model_command?(input)
      else
        false
      end
    end

    def handle_model_command?(input)
      command, value = @terminal.parse_slash_command(input)
      return false unless command == :model

      if value
        @provider.model = value
        @terminal.print_model_switch(@provider.provider_label, @provider.model)
      else
        @terminal.print_model_usage(models: list_provider_models)
      end

      true
    end

    def list_provider_models
      listed_models = @provider.list_models
      if listed_models.is_a?(Hash) && listed_models[:error]
        @terminal.print_error(listed_models[:error])
        return nil
      end

      listed_models.filter_map do |entry|
        next unless entry.is_a?(Hash)

        entry['id'] || entry['name']
      end
    rescue NotImplementedError
      nil
    end

    def flush_chat_log
      return unless @session_started_at && !@messages.empty?

      log_file = File.join(@chats_dir, "#{@session_started_at}.json")
      File.write(log_file, Jules::Message.format_history(@messages, format: :gemini).to_json)
    rescue StandardError => e
      warn "Failed to save chat log: #{e.message}"
    end
  end
end
