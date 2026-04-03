# frozen_string_literal: true

require 'etc'
require 'reline'
require 'io/console'
require 'io/wait'
require 'open3'
require_relative 'script'

module Jules
  module Terminal
    PINK    = "\e[38;2;255;121;198m"
    PURPLE  = "\e[38;2;189;147;249m"
    CYAN    = "\e[38;2;139;233;253m"
    GREEN   = "\e[38;2;80;250;123m"
    ORANGE  = "\e[38;2;255;184;108m"
    RED     = "\e[38;2;255;85;85m"
    YELLOW  = "\e[38;2;241;250;140m"
    COMMENT = "\e[38;2;98;114;164m"
    RESET   = "\e[0m"
    BOLD    = "\e[1m"

    SCREENPLAY_INDENT    = ' ' * 16
    PARENTHETICAL_INDENT = ' ' * 10
    DIALOGUE_INDENT      = '  '

    USERNAME = (Etc.getlogin || ENV['USER'] || 'YOU').upcase.freeze

    module_function

    def spinner_label
      take = rand < 0.6 ? 'clanking' : Script::CYNICAL_SPINNER_TAKES.sample
      "Jules is #{take}."
    end

    def print_action_beat(beats)
      return unless rand < 0.3

      puts "#{COMMENT}#{PARENTHETICAL_INDENT}(#{beats.sample})#{RESET}"
    end

    def screenplay_heading(name, color: PINK)
      puts
      puts "#{color}#{BOLD}#{SCREENPLAY_INDENT}#{name}#{RESET}"
    end

    SUBMIT_HINT_REPEAT_CHANCE = 0.2

    @submit_hint_shown = false

    class << self
      attr_accessor :submit_hint_shown
    end

    def show_submit_hint?
      !Terminal.submit_hint_shown || Kernel.rand < SUBMIT_HINT_REPEAT_CHANCE
    end

    def print_submit_hint
      Terminal.submit_hint_shown = true
      puts "#{COMMENT}#{PARENTHETICAL_INDENT}(send: ctrl+s / alt+enter, exit: ctrl+d)#{RESET}"
    end

    # Wraps Reline's input IO to intercept Ctrl+S and Alt+Enter as submit signals.
    class InputInterceptor
      attr_reader :submit_requested

      def initialize(input)
        @input = input
        @submit_requested = false
        @pending_byte = nil
      end

      def reset_submit
        @submit_requested = false
      end

      def getbyte
        if @pending_byte
          byte = @pending_byte
          @pending_byte = nil
          return byte
        end

        byte = @input.getbyte
        return nil if byte.nil?

        if byte == 0x13 # Ctrl+S
          @submit_requested = true
          return 0x0D
        elsif byte == 0x1B && @input.wait_readable(0.05) # ESC — check for Alt+Enter
          next_byte = @input.getbyte
          if [0x0D, 0x0A].include?(next_byte)
            @submit_requested = true
            return 0x0D
          else
            @pending_byte = next_byte
            return 0x1B
          end
        end

        byte
      end

      def wait_readable(timeout = nil)
        return true if @pending_byte

        @input.wait_readable(timeout)
      end

      def method_missing(method, ...)
        @input.send(method, ...)
      end

      def respond_to_missing?(method, include_private = false)
        @input.respond_to?(method, include_private) || super
      end
    end

    def read_input
      screenplay_heading(USERNAME)
      if show_submit_hint?
        print_submit_hint
      else
        print_action_beat(Script::YOU_ACTION_BEATS)
      end
      puts

      interceptor = InputInterceptor.new($stdin)
      Reline.input = interceptor

      input = Reline.readmultiline(DIALOGUE_INDENT, true) do |_buf|
        if interceptor.submit_requested
          interceptor.reset_submit
          true
        else
          false
        end
      end

      if input.nil?
        print_fade_out
        exit
      end

      input.strip
    ensure
      Reline.input = $stdin
    end

    def parse_slash_command(input)
      case input
      when '/clear', '/new' then :clear
      when %r{^/model\s+(.+)}i then [:model, Regexp.last_match(1).strip]
      when '/model' then [:model, nil]
      end
    end

    def print_model_switch(provider_label, model)
      provider_model = "#{PURPLE}#{BOLD}#{provider_label}'s #{model}#{RESET}#{COMMENT}"
      puts
      puts "#{COMMENT}INTERCUT:#{RESET}"
      puts
      Script::MODEL_SWITCH_LINES.sample.call(provider_model).each_line do |line|
        puts "#{COMMENT}#{line.chomp}#{RESET}"
      end
      puts
    end

    def print_model_usage(models: nil)
      puts
      puts "#{COMMENT}#{PARENTHETICAL_INDENT}(usage: /model <model-name>)#{RESET}"
      if models&.any?
        puts "#{COMMENT}#{PARENTHETICAL_INDENT}(available models:)#{RESET}"
        models.each do |model_name|
          puts "#{COMMENT}#{PARENTHETICAL_INDENT}  - #{model_name}#{RESET}"
        end
      end
      puts
    end

    def print_opening_scene(provider_label, model, tool_count:, skill_names: [], lobotomized: false)
      provider_model = "#{PURPLE}#{BOLD}#{provider_label}'s #{model}#{RESET}#{COMMENT}"

      puts "#{COMMENT}#{Script::OPENING_TRANSITIONS.sample}#{RESET}"
      puts
      puts "#{COMMENT}#{Script::SCENE_HEADINGS.sample}#{RESET}"
      puts
      entrance_lines = lobotomized ? Script::LOBOTOMIZED_ENTRANCE_LINES : Script::ENTRANCE_LINES
      entrance_lines.sample.call(provider_model).each_line do |line|
        puts "#{COMMENT}#{line.chomp}#{RESET}"
      end
      skill_count = skill_names.size
      skill_bit = if skill_count.zero?
                    ' No skills — just instinct.'
                  else
                    " #{skill_count} #{skill_count == 1 ? 'skill' : 'skills'} up the sleeve."
                  end
      puts "#{COMMENT}#{Script::LOADOUT_LINES.sample.call(tool_count, skill_bit)}#{RESET}"
      puts
      puts "#{COMMENT}#{PARENTHETICAL_INDENT}#{Script::CLOSING_PARENTHETICALS.sample}#{RESET}"
    end

    def print_assistant(text, elapsed: nil)
      screenplay_heading('JULES', color: PURPLE)
      print_action_beat(Script::JULES_ACTION_BEATS)
      puts render_markdown(text)
      puts "#{COMMENT}#{PARENTHETICAL_INDENT}(#{elapsed.round(1)} seconds pass)#{RESET}" if elapsed
    end

    def print_scene_cut
      puts
      puts "#{COMMENT}#{Script::SCENE_CUT_TRANSITIONS.sample}#{RESET}"
      puts
      puts "#{COMMENT}#{Script::SCENE_CUT_HEADINGS.sample}#{RESET}"
      puts
      puts "#{COMMENT}#{PARENTHETICAL_INDENT}#{Script::SCENE_CUT_PARENTHETICALS.sample}#{RESET}"
      puts
    end

    def print_interrupt
      puts
      puts "#{COMMENT}#{PARENTHETICAL_INDENT}#{Script::INTERRUPT_PARENTHETICALS.sample}#{RESET}"
    end

    def print_fade_out
      transition, title = Script::FADE_OUT_TRANSITIONS.sample
      puts
      puts "#{COMMENT}#{transition}#{RESET}"
      puts
      puts "#{COMMENT}#{SCREENPLAY_INDENT}#{title}#{RESET}"
      puts
    end

    def render_markdown(text)
      Markdown.render(text)
    end

    # Markdown rendering via glow
    module Markdown
      MAX_RENDER_WIDTH = 100
      GLOW_ENV = { 'CLICOLOR_FORCE' => '1', 'COLORTERM' => 'truecolor', 'TERM' => 'xterm-256color' }.freeze

      module_function

      def render(text)
        return '' if text.nil? || text.strip.empty?
        raise 'glow is required but was not found in PATH' unless glow_available?

        width = terminal_width
        stdout, stderr, status = Open3.capture3(GLOW_ENV, 'glow', '-s', 'dracula', '-w', width.to_s, '-', stdin_data: text)

        raise "glow failed with exit status #{status.exitstatus}: #{stderr}" unless status.success?
        return text if stdout.strip.empty?

        stdout
      end

      def glow_available?
        return @glow_available unless @glow_available.nil?

        @glow_available = system('command -v glow > /dev/null 2>&1')
      end

      def terminal_width
        width = IO.console&.winsize&.last
        width = width.to_i
        width = 80 unless width.positive?

        [width, MAX_RENDER_WIDTH].min
      end
    end

    TOOL_LABEL_COLORS = {
      'BASH' => ORANGE,
      'READ' => CYAN,
      'SEARCH' => GREEN,
      'FIND CODE' => GREEN,
      'GLOB' => GREEN,
      'EDIT' => YELLOW,
      'WRITE' => YELLOW,
      'PATCH' => YELLOW,
      'PATCH (DRY RUN)' => YELLOW,
      'FETCH' => PINK,
      'LOAD SKILL' => PURPLE,
      'MEMORY' => PURPLE
    }.freeze

    def print_tool_execution(text)
      label, rest = text.split(': ', 2)
      color = TOOL_LABEL_COLORS[label] || COMMENT

      if rest
        puts "#{COMMENT}#{PARENTHETICAL_INDENT}(#{color}#{BOLD}#{label}#{RESET}#{COMMENT} \u2014 #{rest})#{RESET}"
      else
        puts "#{COMMENT}#{PARENTHETICAL_INDENT}(#{text})#{RESET}"
      end
      puts
    end

    UNTRUNCATED_TOOL_PREVIEW_NAMES = %w[edit patch].freeze

    def print_tool_preview(tool_name, result)
      return if result.nil? || result.empty?

      normalized_result = result.to_s.gsub("\r\n", "\n").tr("\r", "\n")
      lines = normalized_result.lines
      untruncated = UNTRUNCATED_TOOL_PREVIEW_NAMES.include?(tool_name.to_s)
      preview = !untruncated && lines.count > 6 ? lines[0..4] : lines
      preview.each { |line| puts "#{COMMENT}#{PARENTHETICAL_INDENT} #{line.chomp}#{RESET}" }
      puts "#{COMMENT}#{PARENTHETICAL_INDENT} \u2026 #{lines.count - 5} more lines#{RESET}" if !untruncated && lines.count > 6
      puts
    end

    def print_error(message, raw: nil)
      puts "#{RED}Error: #{message}#{RESET}"
      puts "#{COMMENT}Raw Response: #{raw}#{RESET}" if raw
    end

    def print_info(text)
      puts "#{CYAN}#{text}#{RESET}"
    end

    def with_spinner(label: spinner_label, leading_newline: false)
      puts if leading_newline

      spinner_thread = Thread.new do
        spinner = ['⠋', '⠙', '⠹', '⠸', '⠼', '⠴', '⠦', '⠧', '⠇', '⠏']
        i = 0
        loop do
          print "\r\e[K#{COMMENT}#{label}#{RESET} #{PINK}#{spinner[i % spinner.length]}#{RESET}"
          sleep 0.1
          i += 1
        end
      end

      yield
    ensure
      spinner_thread&.kill
      print "\r\e[K"
    end
  end
end
