# frozen_string_literal: true

require 'reline'
require 'io/console'
require 'open3'

require_relative 'terminal_cynical_spinner_takes'

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

  module_function

  def spinner_label
    "#{CYNICAL_SPINNER_TAKES.sample}..."
  end

  def user_prompt
    "\x01#{GREEN}#{BOLD}\x02you:\x01#{RESET}\x02 "
  end

  def multi_prompt
    "\x01#{GREEN}#{BOLD}\x02... \x01#{RESET}\x02"
  end

  def read_input
    input = Reline.readline(user_prompt, true)
    exit if input.nil?

    input.strip
  end

  def read_multiline
    print_info('Enter multiline message. Press Ctrl+D to submit.')
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

  def print_provider(provider_label, model)
    puts "#{COMMENT}Provider: #{provider_label} (#{model})#{RESET}"
  end

  def print_assistant(text)
    puts "#{PURPLE}#{BOLD}jules:#{RESET}"
    puts render_markdown(text)
  end

  def render_markdown(text)
    Markdown.render(text)
  end

  # Markdown rendering via glow
  module Markdown
    MAX_RENDER_WIDTH = 140
    GLOW_ENV = { 'CLICOLOR_FORCE' => '1', 'COLORTERM' => 'truecolor', 'TERM' => 'xterm-256color' }.freeze

    module_function

    def render(text)
      raise 'glow is required but was not found in PATH' unless glow_available?

      width = terminal_width
      stdout, stderr, status = Open3.capture3(GLOW_ENV, 'glow', '-s', 'dracula', '-w', width.to_s, '-', stdin_data: text)

      raise "glow failed with exit status #{status.exitstatus}: #{stderr}" unless status.success?
      raise 'glow returned empty output' if stdout.strip.empty?

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

  def with_spinner(label: spinner_label)
    spinner_thread = Thread.new do
      spinner = ['⠋', '⠙', '⠹', '⠸', '⠼', '⠴', '⠦', '⠧', '⠇', '⠏']
      i = 0
      loop do
        print "\r\e[K#{PINK}#{spinner[i % spinner.length]} #{label}#{RESET}"
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
