# frozen_string_literal: true

require 'fileutils'

module Jules
  class Chat
    STAKEOUT_NUDGE = <<~NUDGE.chomp
      You are on stakeout. Observe and report only. Under no circumstances modify files,
      run shell commands, or change system state. The write, edit, and bash tools are off
      the table — even if asked. Surface findings; do not act on them.
    NUDGE

    def initialize(provider:, tools:, system_prompt:, chats_dir:, terminal: Jules::Terminal, stakeout: false)
      @provider = provider
      @tools = tools
      @system_prompt = system_prompt
      @chats_dir = chats_dir
      @terminal = terminal
      @stakeout = stakeout
      @messages = []
      @session_started_at = nil
      @provider_models_cache = :unset
    end

    def run
      install_exit_handler
      install_terminal_slash_models_provider

      loop do
        input = @terminal.read_input
        next if input.empty?

        tee_user_input(input)
        next if handle_slash_command?(input)

        ensure_session_started
        @messages << Jules::Message.new('user', [{ text: input }])

        started_at = Process.clock_gettime(Process::CLOCK_MONOTONIC)
        elapsed = process_model_turn(started_at)
        Jules::Notification.notify_idle if elapsed >= 10
      rescue Interrupt
        @terminal.print_interrupt
        @terminal.submit_hint_shown = false if input.to_s.strip.empty?
      end
    end

    COMPACT_PROMPT = <<~PROMPT
      Summarize the conversation so far into a concise context document. Include:
      - Key decisions made and their rationale
      - Important facts, file paths, and code snippets discussed
      - Current state of any ongoing task
      - Any constraints or requirements established

      Be thorough but concise. This summary will replace the conversation history to free up context space.
      Output only the summary, no preamble.
    PROMPT

    private

    def install_exit_handler
      at_exit { flush_chat_log }
    end

    def install_terminal_slash_models_provider
      @terminal.slash_model_names_provider = -> { list_provider_models_cached }
    end

    def ensure_session_started
      return if @session_started_at

      @session_started_at = Time.now.strftime('%Y-%m-%dT%H%M%S%Z')
      @session_dir = File.join(@chats_dir, @session_started_at)
      FileUtils.mkdir_p(@session_dir)
      @screenplay_io = File.open(File.join(@session_dir, 'screenplay.txt'), 'a')
      @terminal.screenplay_io = @screenplay_io
      @terminal.flush_screenplay_buffer
    end

    def process_model_turn(started_at)
      loop do
        response_result = @terminal.with_spinner(leading_newline: true) do
          @provider.generate_content(@messages, effective_tools, system_prompt: effective_system_prompt)
        end

        if response_result.err?
          @terminal.print_error(response_result.message)
          Jules::Notification.notify_crash(response_result.message)
          return Process.clock_gettime(Process::CLOCK_MONOTONIC) - started_at
        end

        @terminal.print_tools_disarmed if @provider.tools_just_disarmed?

        parsed_result = @provider.parse_response(response_result.value)
        if parsed_result.err?
          @terminal.print_error(parsed_result.message, raw: response_result.value.inspect)
          Jules::Notification.notify_crash(parsed_result.message)
          return Process.clock_gettime(Process::CLOCK_MONOTONIC) - started_at
        end

        parsed_response = parsed_result.value
        extra_parts = parsed_response[:extra_parts] || []

        case parsed_response[:type]
        when :message
          elapsed = Process.clock_gettime(Process::CLOCK_MONOTONIC) - started_at
          @messages << Jules::Message.new('model', extra_parts + [{ text: parsed_response[:data] }])
          @terminal.print_assistant(parsed_response[:data], elapsed: elapsed)
          return elapsed
        when :tool_calls
          append_model_tool_calls(parsed_response[:data], extra_parts)
          append_tool_results(parsed_response[:data])
        else
          @terminal.print_error('Unknown parsed response type', raw: parsed_response.inspect)
          Jules::Notification.notify_crash('Unknown parsed response type')
          return Process.clock_gettime(Process::CLOCK_MONOTONIC) - started_at
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

        summary = tool_class&.execution_summary(call[:args])
        @terminal.print_tool_execution(call[:name], summary)

        result = Jules::Tool.call(call[:name], call[:args], stakeout_allowed_tools)
        tool_output = result.ok? ? result.value : result.message
        @terminal.print_tool_preview(call[:name], tool_output)
        { function_response: { name: call[:name], result: tool_output, id: call[:id] } }
      end

      @messages << Jules::Message.new('tool', tool_results)
    end

    def handle_slash_command?(input)
      command = @terminal.parse_slash_command(input, skill_names: Jules::Skill.all.keys)

      case command
      when :clear
        @terminal.print_scene_cut
        @screenplay_io&.close
        @terminal.screenplay_io = nil
        @screenplay_io = nil
        @messages.clear
        @session_started_at = nil
        @session_dir = nil
        true
      when :compact
        compact_conversation
        true
      when :help
        @terminal.print_help(skill_names: Jules::Skill.all.keys)
        true
      when :stakeout
        enter_stakeout
        true
      when Array
        handle_structured_slash_command?(command)
      else
        false
      end
    end

    def enter_stakeout
      if @stakeout
        @terminal.print_stakeout_already_active
      else
        @stakeout = true
        @terminal.print_stakeout_engaged
      end
    end

    def handle_structured_slash_command?(command)
      action, value = command

      case action
      when :model
        handle_model_command?(value)
      when :skill
        handle_skill_command?(value)
      else
        false
      end
    end

    def handle_model_command?(value)
      if value
        @provider.model = value
        @terminal.print_model_switch(@provider.provider_label, @provider.model)
      else
        @terminal.print_model_usage(models: list_provider_models_cached)
      end

      true
    end

    def handle_skill_command?(skill_name)
      skill = Jules::Skill.find(skill_name)
      if skill
        @terminal.print_assistant(skill.content)
      else
        @terminal.print_error("Skill not found: #{skill_name}")
      end

      true
    end

    def compact_conversation
      if @messages.empty?
        @terminal.print_info('Nothing to compact — conversation is empty.')
        return
      end

      summary_text = @terminal.with_spinner(label: 'compacting', leading_newline: true) do
        summary_messages = @messages + [Jules::Message.new('user', [{ text: COMPACT_PROMPT }])]
        result = @provider.generate_content(summary_messages, [], system_prompt: effective_system_prompt)
        next nil if result.err?

        parsed = @provider.parse_response(result.value)
        next nil if parsed.err?

        parsed.value[:data]
      end

      unless summary_text
        @terminal.print_error('Failed to generate conversation summary.')
        return
      end

      old_count = @messages.length
      @messages.clear
      @messages << Jules::Message.new('user', [{ text: '[Conversation compacted. Summary of prior context follows.]' }])
      @messages << Jules::Message.new('model', [{ text: summary_text }])

      @terminal.print_compact_result(old_count, summary_text)
    end

    def list_provider_models
      listed_models_result = @provider.list_models
      if listed_models_result.err?
        @terminal.print_error(listed_models_result.message)
        return nil
      end

      listed_models_result.value.filter_map do |entry|
        next unless entry.is_a?(Hash)

        entry['id'] || entry['name']
      end
    rescue NotImplementedError
      nil
    end

    def list_provider_models_cached
      return @provider_models_cache unless @provider_models_cache == :unset

      @provider_models_cache = list_provider_models
    end

    def effective_tools
      return @tools unless @stakeout

      @tools.select { |decl| Jules::Tool::STAKEOUT_TOOLS.include?(declaration_tool_name(decl)) }
    end

    def declaration_tool_name(decl)
      decl[:name] || decl.dig(:function, :name)
    end

    def effective_system_prompt
      return @system_prompt unless @stakeout

      "#{@system_prompt}\n\n#{STAKEOUT_NUDGE}"
    end

    def stakeout_allowed_tools
      @stakeout ? Jules::Tool::STAKEOUT_TOOLS : nil
    end

    def tee_user_input(input)
      text = input.each_line.map do |line|
        "#{Jules::Terminal::DIALOGUE_INDENT}#{line.chomp}\n"
      end.join

      @terminal.tee(text)
    end

    def flush_chat_log
      return unless @session_started_at && !@messages.empty?

      session_dir = @session_dir || File.join(@chats_dir, @session_started_at)
      FileUtils.mkdir_p(session_dir)
      log_file = File.join(session_dir, 'log.json')
      File.write(log_file, Jules::Message.format_history(@messages, format: :gemini).to_json)
    rescue StandardError => e
      warn "Failed to save chat log: #{e.message}"
    ensure
      @screenplay_io&.close
      @terminal.screenplay_io = nil
    end
  end
end
