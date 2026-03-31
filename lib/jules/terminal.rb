# frozen_string_literal: true

require 'reline'
require 'io/console'
require 'open3'

module Jules
  module Terminal
    CYNICAL_SPINNER_TAKES = [
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

    SCREENPLAY_INDENT = ' ' * 16
    DIALOGUE_INDENT = '  '

    module_function

    def spinner_label
      take = rand < 0.8 ? 'clanking' : CYNICAL_SPINNER_TAKES.sample
      "#{take}..."
    end

    def screenplay_heading(name, color: PINK)
      puts
      puts "#{color}#{BOLD}#{SCREENPLAY_INDENT}#{name}#{RESET}"
    end

    def multi_prompt
      "#{DIALOGUE_INDENT}\x01#{GREEN}#{BOLD}\x02... \x01#{RESET}\x02"
    end

    def read_input
      screenplay_heading('YOU')
      puts
      input = Reline.readline(DIALOGUE_INDENT, true)
      exit if input.nil?

      input.strip
    end

    def read_multiline
      print_info("#{DIALOGUE_INDENT}Enter multiline message. Press Ctrl+D to submit.")
      lines = []

      loop do
        line = Reline.readline(multi_prompt, false)
        break if line.nil?

        lines << line
      end

      lines.join("\n").strip
    end

    def parse_slash_command(input)
      case input
      when '/clear', '/new' then :clear
      when '/multi' then :multi
      end
    end

    def print_opening_scene(provider_label, model)
      puts "#{COMMENT}FADE IN:#{RESET}"
      puts
      puts "#{COMMENT}A terminal flickers to life. JULES (#{provider_label}, #{model}) is online,"
      puts "wired into your computer through local tools, and waiting for your next line.#{RESET}"
    end

    def print_assistant(text)
      screenplay_heading('JULES', color: PURPLE)
      puts render_markdown(text)
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

    def print_tool_execution(text)
      puts "#{COMMENT}#{text}#{RESET}"
    end

    def print_tool_preview(tool_name, result)
      return if result.nil? || result.empty?

      lines = result.to_s.lines

      puts "  #{COMMENT}╭─ Tool Result Preview (#{tool_name}) ─"
      print_preview_lines(lines)
      puts "  #{COMMENT}╰─"
    end

    def print_preview_lines(lines)
      if lines.count > 6
        print_truncated_preview(lines)
      else
        print_full_preview(lines)
      end
    end

    def print_truncated_preview(lines)
      lines[0..4].each { |line| puts "  #{COMMENT}│ #{line.chomp}" }
      puts "  #{COMMENT}│ [...] (#{lines.count - 5} more lines)"
    end

    def print_full_preview(lines)
      lines.each { |line| puts "  #{COMMENT}│ #{line.chomp}" }
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
          print "\r\e[K#{PINK}#{DIALOGUE_INDENT}#{spinner[i % spinner.length]}#{RESET} #{COMMENT}#{label}#{RESET}"
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
