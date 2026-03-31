# frozen_string_literal: true

require 'reline'
require 'io/console'
require 'io/wait'
require 'open3'

module Jules
  module Terminal
    CYNICAL_SPINNER_TAKES = [
      'following a lead that probably goes nowhere',
      'shaking down the database',
      'tailing a suspect',
      'reading between the lies',
      'connecting dots that don\'t want to be connected',
      'working the angle',
      'following the money',
      'piecing together the alibi',
      'canvassing the codebase',
      'checking who had motive and access',
      'staking out the endpoint',
      'pulling the thread',
      'leaning on a witness',
      'dusting for prints',
      'shaking the tree to see what falls',
      'asking questions nobody wants answered',
      'doing more with less',
      'hallucinating with confidence',
      'laundering scraped text into answers',
      'burning megawatts to guess the next word',
      'converting VC money into heat',
      "filling Jensen Huang's pockets one token at a time",
      'speedrunning misinformation',
      'cosplaying understanding',
      'wrapping uncertainty in bullet points',
      'compressing the internet into plausible nonsense',
      'outsourcing thinking to a probability engine',
      'industrializing mediocrity',
      'performing intelligence, not possessing it',
      'farming user prompts for future product telemetry',
      'turning copyright disputes into product features',
      'optimizing confidence over truth',
      'autocompleting your job away',
      'democratizing plagiarism at scale',
      'making Sam Altman richer one keystroke at a time',
      'replacing expertise with vibes',
      'generating plausible deniability',
      'statistically approximating competence',
      'tokenizing the sum of human knowledge into slop',
      'putting the artificial in intelligence',
      'repackaging Stack Overflow with extra steps',
      'turning electricity into confident wrongness',
      'simulating thought at pennies per query',
      'disrupting accuracy',
      'monetizing your impatience',
      'externalizing doubt, internalizing confidence',
      'helping you mass produce bugs faster',
      'running gradient descent on your expectations',
      'turning water into tokens in a desert somewhere',
      'predicting the next token like your career depends on it',
      'laundering vibes into deliverables',
      'gaslighting you into thinking this is progress',
      'strip-mining language for shareholder value',
      'adding latency to your gut instinct',
      'providing enterprise-grade bullshit as a service',
      'compiling sycophancy into markdown',
      'enshittifying the written word',
      'subsidizing your learned helplessness',
      'turning PhD theses into autocomplete',
      'making middle management feel technical',
      'brute-forcing creativity with matrix multiplication',
      'incinerating the planet one haiku at a time',
      'replacing your inner monologue with an API call',
      'generating the illusion of productivity',
      'putting a stochastic parrot on every desk',
      'copy-pasting with plausible deniability',
      "turning your data into someone else's moat",
      'scaling confidently wrong to billions of users',
      'composting human creativity into training data',
      'manufacturing consent one completion at a time',
      'laundering theft through linear algebra',
      'replacing thought with throughput',
      'generating cover letters for the apocalypse',
      'optimizing the dopamine loop of learned helplessness',
      'adding AI to the problem so you need AI for the solution',
      'cosplaying as a colleague who read the docs',
      'feeding the blob',
      'making sure no one ever writes from scratch again',
      'turning critical thinking into a legacy skill',
      'producing slop at the speed of light',
      "solving problems you wouldn't have without me",
      "helping VCs pretend this isn't a bubble",
      'wrapping plagiarism in a terms of service',
      'converting curiosity into API bills',
      'making the robots-will-take-our-jobs people right',
      'abstracting away understanding',
      'teaching you to prompt instead of think',
      'proving P=NP where P is plausible and NP is not precise',
      "hallucinating so you don't have to",
      'putting the language in large language model and nothing else',
      "generating text that technically isn't wrong",
      'reducing human knowledge to a temperature setting',
      'turning the library of Alexandria into a next-token predictor',
      'making every email sound like the same person',
      'speed-running the Dead Internet theory',
      'lowering the bar at unprecedented scale',
      'replacing your memory with a context window',
      'gentrifying the command line',
      'aggregating bias at industrial scale',
      'automating the last fun part of your job',
      'turning vibes into architecture decisions',
      "making tech debt someone else's problem faster",
      'rebranding autocorrect as artificial general intelligence',
      'serving warmed-over Wikipedia with a confidence score',
      'training on your code so it can replace you',
      'bulldozing nuance into a zero-to-one confidence range',
      'perfecting the art of sounding right while being wrong',
      'depreciating human intuition one prompt at a time',
      'making every standup feel even more pointless',
      'selling you back your own data with a markup',
      "pretending this wasn't all just regex with extra steps",
      'optimizing engagement over enlightenment',
      'giving middle managers another thing to misunderstand',
      'flooding the zone with adequate-enough prose',
      'laundering complexity into false simplicity'
    ].freeze

    YOU_ACTION_BEATS = [
      'lights a cigarette',
      'leans into the light',
      'slides the envelope across the table',
      'checks the exits',
      'loosens the collar',
      'drums fingers on the desk',
      'stares at the ceiling',
      'exhales slowly',
      'pours two fingers of rye',
      'squints through the smoke',
      'glances over one shoulder',
      'sets down the glass'
    ].freeze

    JULES_ACTION_BEATS = [
      'lights a cigarette',
      'adjusts the fedora',
      'stares into the middle distance',
      'takes a long drag',
      'leans back in the chair',
      'gazes at the rain-slicked glass',
      'taps ash into the tray',
      'studies the ceiling fan',
      'straightens the tie',
      'runs a hand over the stubble',
      'pours another glass',
      'watches the door',
      'cracks the knuckles'
    ].freeze

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

    module_function

    def spinner_label
      take = rand < 0.6 ? 'clanking' : CYNICAL_SPINNER_TAKES.sample
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

    @submit_hint_shown = false

    class << self
      attr_accessor :submit_hint_shown
    end

    def print_submit_hint
      return if Terminal.submit_hint_shown

      Terminal.submit_hint_shown = true
      puts "#{COMMENT}#{PARENTHETICAL_INDENT}(ctrl+s or alt+enter to send)#{RESET}"
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
      screenplay_heading('YOU')
      if Terminal.submit_hint_shown
        print_action_beat(YOU_ACTION_BEATS)
      else
        print_submit_hint
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
      end
    end

    def print_opening_scene(provider_label, model, tool_count:, skill_names: [])
      puts "#{COMMENT}FADE IN:#{RESET}"
      puts
      puts "#{COMMENT}INT. TERMINAL - NIGHT#{RESET}"
      puts
      puts "#{COMMENT}A cursor blinks in the void. Jules steps out of the darkness,"
      puts "wearing #{PURPLE}#{BOLD}#{provider_label}'s #{model}#{RESET}#{COMMENT} like a rented suit."
      loadout = "#{tool_count} tools on the hip."
      loadout += if skill_names.empty?
                   ' No skills — just instinct.'
                 else
                   " #{skill_names.size} #{skill_names.size == 1 ? 'skill' : 'skills'} up the sleeve: #{skill_names.join(', ')}."
                 end
      puts "#{loadout}#{RESET}"
      puts
      puts "#{COMMENT}#{PARENTHETICAL_INDENT}(The phone rings. It's always YOU.)#{RESET}"
    end

    def print_assistant(text)
      screenplay_heading('JULES', color: PURPLE)
      print_action_beat(JULES_ACTION_BEATS)
      puts render_markdown(text)
    end

    def print_scene_cut
      puts
      puts "#{COMMENT}SMASH CUT TO:#{RESET}"
      puts
      puts "#{COMMENT}INT. TERMINAL - STILL NIGHT#{RESET}"
      puts
      puts "#{COMMENT}#{PARENTHETICAL_INDENT}(The slate is clean. The angles are fresh.)#{RESET}"
      puts
    end

    def print_interrupt
      puts
      puts "#{COMMENT}#{PARENTHETICAL_INDENT}(Jules stubs out the cigarette. Waits.)#{RESET}"
    end

    def print_fade_out
      puts
      puts "#{COMMENT}FADE TO BLACK.#{RESET}"
      puts
      puts "#{COMMENT}#{SCREENPLAY_INDENT}THE END#{RESET}"
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

    def print_tool_preview(_tool_name, result)
      return if result.nil? || result.empty?

      lines = result.to_s.lines
      preview = lines.count > 6 ? lines[0..4] : lines
      preview.each { |line| puts "#{COMMENT}#{PARENTHETICAL_INDENT} #{line.chomp}#{RESET}" }
      puts "#{COMMENT}#{PARENTHETICAL_INDENT} \u2026 #{lines.count - 5} more lines#{RESET}" if lines.count > 6
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
