#!/usr/bin/env ruby
# frozen_string_literal: true

require 'json'
require 'readline'
require 'fileutils'

require_relative 'message'
require_relative 'tool'
require_relative 'gemini_client'
require_relative 'skill'

# Ensure the skills directory exists
skills_dir = File.expand_path('~/.agents/skills')
FileUtils.mkdir_p(skills_dir)

# Ensure the chats directory exists
chats_dir = File.expand_path('~/.jules/chats')
FileUtils.mkdir_p(chats_dir)

# Load all skills
skills = Skill.load_all

module UI
  PINK   = "\e[38;2;255;121;198m"
  PURPLE = "\e[38;2;189;147;249m"
  CYAN   = "\e[38;2;139;233;253m"
  GREEN  = "\e[38;2;80;250;123m"
  ORANGE = "\e[38;2;255;184;108m"
  RED    = "\e[38;2;255;85;85m"
  YELLOW = "\e[38;2;241;250;140m"
  COMMENT = "\e[38;2;98;114;164m"
  RESET  = "\e[0m"
  BOLD   = "\e[1m"

  def self.user_prompt
    "\x01#{GREEN}#{BOLD}\x02you:\x01#{RESET}\x02 "
  end

  def self.multi_prompt
    "\x01#{GREEN}#{BOLD}\x02... \x01#{RESET}\x02"
  end
end

client = GeminiClient.new
messages = []
session_started_at = nil
has_unsent_tool_results = false

def print_tool_preview(tool_name, result)
  return if result.nil? || result.empty?

  header = "  #{UI::COMMENT}╭─ Tool Result Preview (#{tool_name}) ─"
  puts header

  lines = result.to_s.lines
  if lines.count > 6
    lines[0..4].each { |line| puts "  #{UI::COMMENT}│ #{line.chomp}" }
    puts "  #{UI::COMMENT}│ [...] (#{lines.count - 5} more lines)"
  else
    lines.each { |line| puts "  #{UI::COMMENT}│ #{line.chomp}" }
  end

  puts "  #{UI::COMMENT}╰─"
end

loop do
  unless has_unsent_tool_results
    input = Readline.readline(UI.user_prompt, true)
    exit if input.nil?
    input = input.strip

    next if input.empty?

    case input
    when /^(quit|exit)$/i, '/quit', '/exit'
      exit
    when '/help'
      puts "#{UI::CYAN}Commands:"
      puts '  /clear - Clear the conversation history'
      puts '  /multi - Enter multiline mode (for pasting code or writing paragraphs). End with Ctrl+D.'
      puts '  /help  - Show this help message'
      puts "  /exit  - Exit the assistant#{UI::RESET}"
      next
    when '/clear'
      messages = []
      session_started_at = nil
      puts "#{UI::CYAN}Conversation cleared.#{UI::RESET}"
      next
    when '/multi'
      puts "#{UI::CYAN}Enter multiline message. Press Ctrl+D to submit.#{UI::RESET}"
      lines = []
      loop do
        line = Readline.readline(UI.multi_prompt, false)
        break if line.nil?

        lines << line
      end
      input = lines.join("\n").strip
      next if input.empty?
    end

    # Start a new session if this is the first message
    session_started_at ||= Time.now.strftime('%Y-%m-%dT%H%M%S%Z')

    messages << Message.new('user', [{ text: input }])
  end

  # Persist the conversation history to a session file
  if session_started_at
    log_file = File.join(chats_dir, "#{session_started_at}.json")
    File.write(log_file, messages.map(&:as_gemini).to_json)
  end

  system_text = 'You are Jules, a straight and to-the-point general-purpose terminal assistant.'
  system_text += "\n\nAdditional instructions from AGENTS.md:\n#{File.read('AGENTS.md')}" if File.exist?('AGENTS.md')

  unless skills.empty?
    system_text += "\n\nThe following skills are available:\n"
    skills.each do |skill|
      system_text += "<skill><name>#{skill.name}</name><description>#{skill.description}</description></skill>\n"
    end
  end

  body = {
    system_instruction: {
      parts: [{
        text: system_text
      }]
    },
    contents: messages.map(&:as_gemini),
    tools: [{ function_declarations: Tool.all_gemini_declarations }]
  }

  has_unsent_tool_results = false

  spinner_thread = Thread.new do
    spinner = ['⠋', '⠙', '⠹', '⠸', '⠼', '⠴', '⠦', '⠧', '⠇', '⠏']
    i = 0
    loop do
      print "\r\e[K#{UI::COMMENT}#{spinner[i % spinner.length]} clanking...#{UI::RESET}"
      sleep 0.1
      i += 1
    end
  end

  begin
    parsed = client.generate_content(body)
  ensure
    spinner_thread.kill
    print "\r\e[K"
  end

  candidate = parsed['candidates']&.first
  if candidate.nil?
    puts "#{UI::RED}got this back from api: #{parsed}#{UI::RESET}"
    raise 'no candidates'
  end

  parts = candidate.dig('content', 'parts')
  next if parts.nil?

  # Store the entire model response (including thought signatures) as one message
  messages << Message.new('model', parts)

  tool_response_parts = []
  jules_label_printed = false

  parts.each do |part|
    if (text = part['text'])
      unless jules_label_printed
        puts "#{UI::PURPLE}#{UI::BOLD}jules:#{UI::RESET}"
        jules_label_printed = true
      end
      puts text
    elsif (call = part['functionCall'])
      tool_class = Tool.find(call['name'])
      puts "#{UI::COMMENT}#{tool_class.render_execution(call['args'])}#{UI::RESET}"
      result = Tool.call(call['name'], call['args'])
      print_tool_preview(call['name'], result)
      tool_response_parts << { functionResponse: { name: call['name'], response: { result: } } }
    elsif part.key?('thought') || part.key?('thoughtSignature')
      # thinking parts - already stored with the model message above
    else
      puts "#{UI::RED}Error: Unknown part received: #{part.inspect}#{UI::RESET}"
    end
  end

  if tool_response_parts.any?
    messages << Message.new('user', tool_response_parts)
    has_unsent_tool_results = true
  end
rescue Interrupt
  puts "\n^C"
  has_unsent_tool_results = false
end
