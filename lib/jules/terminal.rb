# frozen_string_literal: true

require 'etc'
require 'reline'
require 'io/console'
require 'io/wait'
require 'open3'
require 'tempfile'
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

    def tee(text)
      io = Terminal.screenplay_io
      if io
        io.write(text)
        io.flush
      elsif Terminal.screenplay_buffer
        Terminal.screenplay_buffer << text
      end
    end

    def start_screenplay_buffer
      Terminal.screenplay_buffer = +''
    end

    def flush_screenplay_buffer
      io = Terminal.screenplay_io
      return unless io && Terminal.screenplay_buffer

      io.write(Terminal.screenplay_buffer)
      io.flush
      Terminal.screenplay_buffer = nil
    end

    def spinner_label
      take = rand < 0.6 ? 'clanking' : Script::CYNICAL_SPINNER_TAKES.sample
      "Jules is #{take}."
    end

    def print_action_beat(beats)
      return unless rand < 0.3

      beat = beats.sample
      puts "#{COMMENT}#{PARENTHETICAL_INDENT}(#{beat})#{RESET}"
      tee("#{PARENTHETICAL_INDENT}(#{beat})\n")
    end

    def screenplay_heading(name, color: PINK)
      puts
      puts "#{color}#{BOLD}#{SCREENPLAY_INDENT}#{name}#{RESET}"
      tee("\n#{SCREENPLAY_INDENT}#{name}\n")
    end

    SUBMIT_HINT_REPEAT_CHANCE = 0.2

    @submit_hint_shown = false

    class << self
      attr_accessor :submit_hint_shown, :slash_model_names_provider, :screenplay_io, :screenplay_buffer
    end

    @screenplay_io = nil
    @screenplay_buffer = nil

    FZF_INSTALL_MESSAGE = 'Install fzf to use @ path mentions: https://github.com/junegunn/fzf'

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
        @injected_bytes = []
      end

      def reset_submit
        @submit_requested = false
      end

      def getbyte
        return @injected_bytes.shift unless @injected_bytes.empty?

        if @pending_byte
          byte = @pending_byte
          @pending_byte = nil
          return byte
        end

        byte = @input.getbyte
        return nil if byte.nil?

        case byte
        when 0x0F # Ctrl+O — open in $EDITOR
          current_buf = Reline.line_buffer.to_s
          content = Terminal.open_in_editor(current_buf)
          if content
            # Ctrl+E (end of line) + Ctrl+U (kill line) to clear, then inject new content
            clear = [0x05, 0x15] # move to end, kill line
            @injected_bytes.concat(clear)
            @injected_bytes.concat(content.bytes)
          end
          Reline.redisplay
          return @injected_bytes.shift unless @injected_bytes.empty?

          getbyte
        when 0x13 # Ctrl+S
          @submit_requested = true
          0x0D
        when 0x40 # @
          return 0x40 unless Terminal.mention_trigger_boundary?(Reline.line_buffer, Reline.point)

          # If another byte is immediately available, treat this as pasted text and skip picker.
          return 0x40 if @input.wait_readable(0)

          mention = Terminal.pick_path_mention
          @injected_bytes.concat(mention.bytes) if mention
          Reline.redisplay
          return @injected_bytes.shift unless @injected_bytes.empty?

          # If mention selection was canceled, fall back to inserting the literal '@'
          # so the current buffer is immediately visible again.
          0x40
        when 0x2F # /
          return 0x2F unless Terminal.slash_trigger_boundary?(Reline.line_buffer, Reline.point)

          # If another byte is immediately available, treat this as pasted text and skip picker.
          return 0x2F if @input.wait_readable(0)

          command = Terminal.pick_slash_command
          @injected_bytes.concat(command.bytes) if command
          Reline.redisplay
          return @injected_bytes.shift unless @injected_bytes.empty?

          # If command selection was canceled, fall back to inserting literal '/'.
          0x2F
        when 0x1B # ESC — treat only Alt+Enter specially; swallow lone ESC
          if @input.wait_readable(0.05)
            next_byte = @input.getbyte
            if [0x0D, 0x0A].include?(next_byte)
              @submit_requested = true
              return 0x0D
            end

            @pending_byte = next_byte
            return getbyte
          end

          getbyte
        else
          byte
        end
      end

      def wait_readable(timeout = nil)
        return true if @injected_bytes.any?
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

    def open_in_editor(existing_content = '')
      editor = ENV['EDITOR'] || 'nvim'
      tmpfile = Tempfile.new(['jules-prompt', '.md'])
      tmpfile.write(existing_content) unless existing_content.empty?
      tmpfile.flush
      tmpfile.close

      console = IO.console
      console.cooked!
      system(editor, tmpfile.path, in: '/dev/tty', out: '/dev/tty', err: '/dev/tty')
      console.raw!

      content = File.read(tmpfile.path).strip
      return nil if content.empty?

      content
    rescue StandardError => e
      print_error("Could not open editor: #{e.message}")
      nil
    ensure
      tmpfile&.unlink
    end

    def mention_trigger_boundary?(line_buffer, cursor_point)
      return true if cursor_point.to_i <= 0

      prefix = line_buffer.to_s[0...cursor_point]
      previous_char = prefix[-1]
      return true if previous_char.nil?

      previous_char.match?(/[[:space:]]/)
    end

    def slash_trigger_boundary?(_line_buffer, cursor_point)
      cursor_point.to_i <= 0
    end

    def pick_path_mention
      unless fzf_available?
        print_info(FZF_INSTALL_MESSAGE)
        return nil
      end

      candidates = mention_candidates
      return nil if candidates.empty?

      selection, status = run_fzf(candidates)
      return "@#{selection}" if status.success? && !selection.empty?
      return nil if [1, 130].include?(status.exitstatus)

      print_info(FZF_INSTALL_MESSAGE)
      nil
    rescue Errno::ENOENT
      print_info(FZF_INSTALL_MESSAGE)
      nil
    end

    def mention_candidates
      files = rg_file_candidates
      return [] if files.empty?

      dirs = files.flat_map do |path|
        parts = path.split('/')
        next [] if parts.length <= 1

        (1...parts.length).map { |i| parts[0...i].join('/') }
      end

      (files + dirs).uniq.sort
    end

    def rg_file_candidates
      stdout, _stderr, status = Open3.capture3('rg', '--files', '--hidden', '--glob', '!.git')
      return [] unless status.success?

      stdout.lines.map(&:strip).reject(&:empty?)
    rescue Errno::ENOENT
      []
    end

    def run_fzf(candidates, prompt: 'evidence> ', header: fzf_header)
      stdout, _stderr, status = Open3.capture3(
        'fzf',
        '--height', '40%',
        '--layout', 'reverse',
        '--border', 'none',
        '--ansi',
        '--prompt', prompt,
        '--header', header,
        '--header-first',
        '--info', 'inline',
        stdin_data: candidates.join("\n")
      )
      [stdout.to_s.strip, status]
    end

    def run_fzf_with_values(candidates, prompt:, header:, initial_query: nil)
      lines = candidates.map { |item| "#{item[:value]}\t#{item[:label]}" }
      command = [
        'fzf',
        '--height', '40%',
        '--layout', 'reverse',
        '--border', 'none',
        '--ansi',
        '--prompt', prompt,
        '--header', header,
        '--header-first',
        '--info', 'inline',
        '--delimiter', "\t",
        '--with-nth', '2..'
      ]
      command += ['--query', initial_query] if initial_query

      stdout, _stderr, status = Open3.capture3(*command, stdin_data: lines.join("\n"))

      selected_line = stdout.to_s.strip
      selected_value = selected_line.split("\t", 2).first.to_s
      [selected_value, status]
    end

    def fzf_header
      stage_direction = [
        "#{USERNAME} pokes through the night desk files.",
        "#{USERNAME} rifles the cold-case archive for a name.",
        "#{USERNAME} thumbs through evidence folders under a flickering lamp.",
        "#{USERNAME} drags a finger down the index cards, hunting the right path.",
        "#{USERNAME} cracks open the evidence locker and scans the labels."
      ].sample

      # fzf renders headers with a small left gutter, so we offset by two spaces
      # to visually align with screenplay parentheticals.
      fzf_header_indent = ' ' * [PARENTHETICAL_INDENT.length - 2, 0].max
      "\n#{COMMENT}#{fzf_header_indent}(#{stage_direction} [2mhit enter to tag it.[22m)#{RESET}"
    end

    def slash_fzf_header
      stage_direction = [
        "#{USERNAME} flips to the command index.",
        "#{USERNAME} scans the slash-command roster.",
        "#{USERNAME} runs a finger down the shortcut ledger.",
        "#{USERNAME} checks the switchboard for the right command."
      ].sample

      fzf_header_indent = ' ' * [PARENTHETICAL_INDENT.length - 2, 0].max
      "\n#{COMMENT}#{fzf_header_indent}(#{stage_direction} [2mhit enter to run it.[22m)#{RESET}"
    end

    def fzf_available?
      system('command -v fzf > /dev/null 2>&1')
    end

    def pick_slash_command
      unless fzf_available?
        print_info(FZF_INSTALL_MESSAGE)
        return nil
      end

      candidates = slash_command_candidates(model_names: safe_slash_model_names)
      return nil if candidates.empty?

      selection, status = run_fzf_with_values(
        candidates,
        prompt: 'command> ',
        header: slash_fzf_header,
        initial_query: '/'
      )
      return selection if status.success? && !selection.empty?
      return nil if [1, 130].include?(status.exitstatus)

      print_info(FZF_INSTALL_MESSAGE)
      nil
    rescue Errno::ENOENT
      print_info(FZF_INSTALL_MESSAGE)
      nil
    end

    def safe_slash_model_names
      provider = Terminal.slash_model_names_provider
      return nil unless provider

      provider.call
    rescue StandardError
      nil
    end

    def slash_command_candidates(model_names: nil, skill_names: Jules::Skill.all.keys)
      builtins = [
        { value: '/help', label: '/help' },
        { value: '/clear', label: '/clear' },
        { value: '/new', label: '/new' },
        { value: '/model', label: '/model' }
      ]

      skills = skill_names.sort.map do |name|
        command = "/#{name}"
        { value: command, label: command }
      end

      models = Array(model_names).map do |name|
        command = "/model #{name}"
        { value: command, label: command }
      end

      builtins + skills + models
    end

    def parse_slash_command(input, skill_names: [])
      case input
      when '/clear', '/new' then :clear
      when '/help' then :help
      when %r{^/model\s+(.+)}i then [:model, Regexp.last_match(1).strip]
      when '/model' then [:model, nil]
      when %r{^/([^\s]+)$}
        command = Regexp.last_match(1)
        [:skill, command] if skill_names.include?(command)
      end
    end

    def print_help(skill_names: [])
      lines = [
        '',
        "#{PARENTHETICAL_INDENT}Slash Commands",
        "#{PARENTHETICAL_INDENT}  /help          — show this help",
        "#{PARENTHETICAL_INDENT}  /clear, /new   — clear conversation and start fresh",
        "#{PARENTHETICAL_INDENT}  /model         — list available models",
        "#{PARENTHETICAL_INDENT}  /model <name>  — switch to a different model"
      ]
      skill_names.each { |name| lines << "#{PARENTHETICAL_INDENT}  /#{name}" } if skill_names.any?
      lines += [
        '',
        "#{PARENTHETICAL_INDENT}Keyboard Shortcuts",
        "#{PARENTHETICAL_INDENT}  ctrl+s         — send message",
        "#{PARENTHETICAL_INDENT}  alt+enter      — send message",
        "#{PARENTHETICAL_INDENT}  ctrl+c         — interrupt current action",
        "#{PARENTHETICAL_INDENT}  ctrl+o         — compose in $EDITOR",
        "#{PARENTHETICAL_INDENT}  ctrl+d         — exit",
        "#{PARENTHETICAL_INDENT}  @              — fuzzy-find file mention (Esc keeps a literal @)",
        "#{PARENTHETICAL_INDENT}  /              — fuzzy command picker (Esc keeps a literal /)",
        ''
      ]

      lines.each do |line|
        if line.empty?
          puts
        elsif line.include?('Slash Commands') || line.include?('Keyboard Shortcuts')
          puts "#{CYAN}#{BOLD}#{line}#{RESET}"
        else
          puts "#{COMMENT}#{line}#{RESET}"
        end
        tee("#{line}\n")
      end
    end

    def print_model_switch(provider_label, model)
      provider_model_colored = "#{PURPLE}#{BOLD}#{provider_label}'s #{model}#{RESET}#{COMMENT}"
      provider_model_plain = "#{provider_label}'s #{model}"
      puts
      puts "#{COMMENT}INTERCUT:#{RESET}"
      tee("\nINTERCUT:\n")
      puts
      tee("\n")
      line_template = Script::MODEL_SWITCH_LINES.sample
      line_template.call(provider_model_colored).each_line do |line|
        puts "#{COMMENT}#{line.chomp}#{RESET}"
      end
      line_template.call(provider_model_plain).each_line do |line|
        tee("#{line.chomp}\n")
      end
      puts
      tee("\n")
    end

    def print_model_usage(models: nil)
      puts
      tee("\n")
      puts "#{COMMENT}#{PARENTHETICAL_INDENT}(usage: /model <model-name>)#{RESET}"
      tee("#{PARENTHETICAL_INDENT}(usage: /model <model-name>)\n")
      if models&.any?
        puts "#{COMMENT}#{PARENTHETICAL_INDENT}(available models:)#{RESET}"
        tee("#{PARENTHETICAL_INDENT}(available models:)\n")
        models.each do |model_name|
          puts "#{COMMENT}#{PARENTHETICAL_INDENT}  - #{model_name}#{RESET}"
          tee("#{PARENTHETICAL_INDENT}  - #{model_name}\n")
        end
      end
      puts
      tee("\n")
    end

    def print_opening_scene(provider_label, model, tool_count:, skill_names: [], lobotomized: false)
      provider_model_colored = "#{PURPLE}#{BOLD}#{provider_label}'s #{model}#{RESET}#{COMMENT}"
      provider_model_plain = "#{provider_label}'s #{model}"

      opening = Script::OPENING_TRANSITIONS.sample
      puts "#{COMMENT}#{opening}#{RESET}"
      tee("#{opening}\n")
      puts
      tee("\n")
      scene = Script::SCENE_HEADINGS.sample
      puts "#{COMMENT}#{scene}#{RESET}"
      tee("#{scene}\n")
      puts
      tee("\n")
      entrance_lines = lobotomized ? Script::LOBOTOMIZED_ENTRANCE_LINES : Script::ENTRANCE_LINES
      entrance_template = entrance_lines.sample
      entrance_template.call(provider_model_colored).each_line do |line|
        puts "#{COMMENT}#{line.chomp}#{RESET}"
      end
      entrance_template.call(provider_model_plain).each_line do |line|
        tee("#{line.chomp}\n")
      end
      skill_count = skill_names.size
      skill_bit = if skill_count.zero?
                    ' No skills — just instinct.'
                  else
                    " #{skill_count} #{skill_count == 1 ? 'skill' : 'skills'} up the sleeve."
                  end
      loadout = Script::LOADOUT_LINES.sample.call(tool_count, skill_bit)
      puts "#{COMMENT}#{loadout}#{RESET}"
      tee("#{loadout}\n")
      puts
      tee("\n")
      closing = Script::CLOSING_PARENTHETICALS.sample
      puts "#{COMMENT}#{PARENTHETICAL_INDENT}#{closing}#{RESET}"
      tee("#{PARENTHETICAL_INDENT}#{closing}\n")
    end

    def print_assistant(text, elapsed: nil)
      if elapsed
        elapsed_text = "(#{elapsed.round(1)} seconds pass)"
        puts "#{COMMENT}#{PARENTHETICAL_INDENT}#{elapsed_text}#{RESET}"
        tee("#{PARENTHETICAL_INDENT}#{elapsed_text}\n")
      end
      screenplay_heading('JULES', color: PURPLE)
      print_action_beat(Script::JULES_ACTION_BEATS)
      puts render_markdown(text)
      tee("#{text}\n")
    end

    def print_scene_cut
      transition = Script::SCENE_CUT_TRANSITIONS.sample
      heading = Script::SCENE_CUT_HEADINGS.sample
      parenthetical = Script::SCENE_CUT_PARENTHETICALS.sample
      puts
      puts "#{COMMENT}#{transition}#{RESET}"
      puts
      puts "#{COMMENT}#{heading}#{RESET}"
      puts
      puts "#{COMMENT}#{PARENTHETICAL_INDENT}#{parenthetical}#{RESET}"
      puts
      tee("\n#{transition}\n\n#{heading}\n\n#{PARENTHETICAL_INDENT}#{parenthetical}\n\n")
    end

    def print_interrupt
      interrupt = Script::INTERRUPT_PARENTHETICALS.sample
      puts
      puts "#{COMMENT}#{PARENTHETICAL_INDENT}#{interrupt}#{RESET}"
      tee("\n#{PARENTHETICAL_INDENT}#{interrupt}\n")
    end

    def print_fade_out
      transition, title = Script::FADE_OUT_TRANSITIONS.sample
      puts
      puts "#{COMMENT}#{transition}#{RESET}"
      puts
      puts "#{COMMENT}#{SCREENPLAY_INDENT}#{title}#{RESET}"
      puts
      tee("\n#{transition}\n\n#{SCREENPLAY_INDENT}#{title}\n\n")
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

    TOOL_STAGE_DIRECTIONS = {
      'bash' => { verb: 'runs',                        color: ORANGE },
      'read' => { verb: 'reads',                       color: CYAN },
      'edit' => { verb: 'edits',                       color: YELLOW },
      'write' => { verb: 'writes',                      color: YELLOW },
      'patch' => { verb: 'patches',                     color: YELLOW,
                   variants: { dry_run: 'dry-runs a patch on' } },
      'glob' => { verb: 'searches for files matching', color: GREEN },
      'search' => { verb: 'searches for', color: GREEN },
      'findcode' => { verb: 'looks up',                    color: GREEN },
      'webfetch' => { verb: 'fetches',                     color: PINK },
      'loadskill' => { verb: 'loads skill', color: PURPLE },
      'memory' => { verb: 'recalls', color: PURPLE },
      'notification' => { verb: 'notifies', color: COMMENT }
    }.freeze

    def print_tool_execution(tool_name, summary)
      direction = TOOL_STAGE_DIRECTIONS[tool_name]

      unless direction
        puts "#{COMMENT}#{PARENTHETICAL_INDENT}(Jules uses #{tool_name})#{RESET}"
        tee("#{PARENTHETICAL_INDENT}(Jules uses #{tool_name})\n")
        puts
        tee("\n")
        return
      end

      verb = (summary[:variant] && direction[:variants]&.dig(summary[:variant])) || direction[:verb]
      detail = summary[:detail]
      color = direction[:color]

      puts "#{COMMENT}#{PARENTHETICAL_INDENT}(Jules #{color}#{BOLD}#{verb}#{RESET}#{COMMENT} #{detail})#{RESET}"
      tee("#{PARENTHETICAL_INDENT}(Jules #{verb} #{detail})\n")
      puts
      tee("\n")
    end

    UNTRUNCATED_TOOL_PREVIEW_NAMES = %w[edit patch].freeze

    def print_tool_preview(tool_name, result)
      return if result.nil? || result.empty?

      normalized_result = result.to_s.gsub("\r\n", "\n").tr("\r", "\n")
      lines = normalized_result.lines
      untruncated = UNTRUNCATED_TOOL_PREVIEW_NAMES.include?(tool_name.to_s)
      preview = !untruncated && lines.count > 6 ? lines[0..4] : lines
      preview.each do |line|
        puts "#{COMMENT}#{PARENTHETICAL_INDENT} #{line.chomp}#{RESET}"
        tee("#{PARENTHETICAL_INDENT} #{line.chomp}\n")
      end
      if !untruncated && lines.count > 6
        truncation = "#{PARENTHETICAL_INDENT} \u2026 #{lines.count - 5} more lines"
        puts "#{COMMENT}#{truncation}#{RESET}"
        tee("#{truncation}\n")
      end
      puts
      tee("\n")
    end

    def print_error(message, raw: nil)
      puts "#{RED}Error: #{message}#{RESET}"
      tee("Error: #{message}\n")
      return unless raw

      puts "#{COMMENT}Raw Response: #{raw}#{RESET}"
      tee("Raw Response: #{raw}\n")
    end

    def print_info(text)
      puts "#{CYAN}#{text}#{RESET}"
      tee("#{text}\n")
    end

    def with_spinner(label: spinner_label, leading_newline: false)
      puts if leading_newline

      spinner_thread = Thread.new do
        spinner = ['⠋', '⠙', '⠹', '⠸', '⠼', '⠴', '⠦', '⠧', '⠇', '⠏']
        i = 0
        loop do
          print spinner_scene_direction(label, spinner[i % spinner.length])
          sleep 0.1
          i += 1
        end
      end

      yield
    ensure
      spinner_thread&.kill
      print "\r\e[K"
    end

    def spinner_scene_direction(label, frame)
      "\r\e[K#{COMMENT}#{PARENTHETICAL_INDENT}(#{label} #{PINK}#{frame}#{COMMENT})#{RESET}"
    end
  end
end
