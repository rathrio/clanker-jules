#!/usr/bin/env ruby
# frozen_string_literal: true

require 'json'
require 'readline'
require 'fileutils'

require_relative 'message'
require_relative 'tool'
require_relative 'skill'
require_relative 'providers/gemini'
require_relative 'providers/open_router'

# --- Configuration ---
# Select provider based on environment variable, default to Gemini
PROVIDER = case ENV['JULES_PROVIDER']&.downcase
           when 'openrouter'
             OpenRouterProvider.new
           else
             GeminiProvider.new
           end

# Ensure directories exist
FileUtils.mkdir_p(File.expand_path('~/.agents/skills'))
CHATS_DIR = File.expand_path('~/.jules/chats')
FileUtils.mkdir_p(CHATS_DIR)

# --- UI Module ---
module UI
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

  def self.user_prompt
    "\x01#{GREEN}#{BOLD}\x02you:\x01#{RESET}\x02 "
  end

  def self.multi_prompt
    "\x01#{GREEN}#{BOLD}\x02... \x01#{RESET}\x02"
  end
end

# --- Helper Methods ---
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

def get_user_input
  input = Readline.readline(UI.user_prompt, true)
  exit if input.nil?
  input.strip
end

def handle_slash_commands(input, messages, session_started_at)
  case input
  when '/clear'
    messages.clear
    session_started_at = nil
    puts "#{UI::CYAN}Conversation cleared.#{UI::RESET}"
    return [true, messages, session_started_at]
  when '/multi'
    puts "#{UI::CYAN}Enter multiline message. Press Ctrl+D to submit.#{UI::RESET}"
    lines = []
    loop do
      line = Readline.readline(UI.multi_prompt, false)
      break if line.nil?
      lines << line
    end
    input = lines.join("\n").strip
    return [input.empty?, messages, session_started_at, input]
  end
  [false, messages, session_started_at, input]
end

puts "#{UI::COMMENT}Provider: #{PROVIDER.class} (#{PROVIDER.model})#{UI::RESET}"

# --- Main Application ---
messages = []
session_started_at = nil
has_unsent_tool_results = false
skills = Skill.load_all

loop do
  unless has_unsent_tool_results
    input = get_user_input
    next if input.empty?

    is_command, messages, session_started_at, input = handle_slash_commands(input, messages, session_started_at)
    next if is_command

    session_started_at ||= Time.now.strftime('%Y-%m-%dT%H%M%S%Z')
    messages << Message.new('user', [{ text: input }])
  end

  if session_started_at
    log_file = File.join(CHATS_DIR, "#{session_started_at}.json")
    File.write(log_file, Message.format_history(messages, format: :gemini).to_json)
  end

  system_prompt = 'You are Jules, a straight and to-the-point general-purpose terminal assistant.'
  system_prompt += "\n\nAdditional instructions from AGENTS.md:\n#{File.read('AGENTS.md')}" if File.exist?('AGENTS.md')

  unless skills.empty?
    system_prompt += "\n\nThe following skills are available:\n"
    skills.each do |skill|
      system_prompt += "<skill><name>#{skill.name}</name><description>#{skill.description}</description></skill>\n"
    end
  end

  tools = Tool.declarations(format: PROVIDER.tool_format)

  spinner_thread = Thread.new do
    spinner = ['⠋', '⠙', '⠹', '⠸', '⠼', '⠴', '⠦', '⠧', '⠇', '⠏']
    i = 0
    loop do
      print "\r\e[K#{UI::COMMENT}#{spinner[i % spinner.length]} clanking...#{UI::RESET}"
      sleep 0.1
      i += 1
    end
  end

  response = nil
  begin
    response = PROVIDER.generate_content(messages, tools, system_prompt: system_prompt)
  ensure
    spinner_thread.kill
    print "\r\e[K"
  end

  parsed_response = PROVIDER.parse_response(response)

  extra_parts = parsed_response[:extra_parts] || []

  case parsed_response[:type]
  when :message
    messages << Message.new('model', extra_parts + [{ text: parsed_response[:data] }])
    puts "#{UI::PURPLE}#{UI::BOLD}jules:#{UI::RESET}"
    puts parsed_response[:data]
    has_unsent_tool_results = false
  when :tool_calls
    model_parts = extra_parts + parsed_response[:data].map do |call|
      { function_call: { name: call[:name], args: call[:args], id: call[:id] } }
    end
    messages << Message.new('model', model_parts)

    tool_results = parsed_response[:data].map do |call|
      tool_class = Tool.find(call[:name])
      puts "#{UI::COMMENT}#{tool_class.render_execution(call[:args])}#{UI::RESET}"
      result = Tool.call(call[:name], call[:args])
      print_tool_preview(call[:name], result)
      { function_response: { name: call[:name], result: result, id: call[:id] } }
    end
    messages << Message.new('tool', tool_results)
    has_unsent_tool_results = true
  when :error
    puts "#{UI::RED}Error: #{parsed_response[:data]}#{UI::RESET}"
    puts "#{UI::COMMENT}Raw Response: #{response.inspect}#{UI::RESET}"
    has_unsent_tool_results = false
  end

rescue Interrupt
  puts "\n^C"
  has_unsent_tool_results = false
end
