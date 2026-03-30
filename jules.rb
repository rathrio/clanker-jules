#!/usr/bin/env ruby
# frozen_string_literal: true

require 'json'
require 'fileutils'
require 'optparse'

require_relative 'message'
require_relative 'tool'
require_relative 'skill'
require_relative 'terminal'
require_relative 'provider'

# --- Configuration ---
options = {
  provider: ENV.fetch('JULES_PROVIDER', 'gemini').downcase,
  model: ENV.fetch('JULES_MODEL', nil)
}

OptionParser.new do |opts|
  opts.banner = "Usage: #{File.basename($PROGRAM_NAME)} [options]"

  opts.on('-p', '--provider PROVIDER', "Provider: #{Provider.all_names.join(', ')}") do |provider|
    options[:provider] = provider.downcase
  end

  opts.on('-m', '--model MODEL', 'Model name for the selected provider') do |model|
    options[:model] = model
  end

  opts.on('-h', '--help', 'Show this help') do
    puts opts
    exit
  end
end.parse!

begin
  PROVIDER = Provider.build(options[:provider], model: options[:model])
rescue KeyError
  warn "Unknown provider '#{options[:provider]}'. Use #{Provider.all_names.join(', ')}."
  exit 1
end

# Ensure directories exist
FileUtils.mkdir_p(File.expand_path('~/.agents/skills'))
CHATS_DIR = File.expand_path('~/.jules/chats')
FileUtils.mkdir_p(CHATS_DIR)

Terminal.print_provider(PROVIDER.provider_label, PROVIDER.model)

# --- Main Application ---
messages = []
session_started_at = nil
has_unsent_tool_results = false
skills = Skill.all

loop do
  unless has_unsent_tool_results
    input = Terminal.read_input
    next if input.empty?

    case Terminal.parse_slash_command(input)
    when :clear
      messages.clear
      session_started_at = nil
      Terminal.print_info('Conversation cleared.')
      next
    when :multi
      input = Terminal.read_multiline
      next if input.empty?
    end

    session_started_at ||= Time.now.strftime('%Y-%m-%dT%H%M%S%Z')
    messages << Message.new('user', [{ text: input }])
  end

  if session_started_at
    log_file = File.join(CHATS_DIR, "#{session_started_at}.json")
    File.write(log_file, Message.format_history(messages, format: :gemini).to_json)
  end

  system_prompt_path = File.expand_path('~/.jules/SYSTEM.md')
  system_prompt = if File.exist?(system_prompt_path)
                    File.read(system_prompt_path)
                  else
                    'You are Jules, a straight and to-the-point general-purpose terminal assistant.'
                  end
  system_prompt += "\n\nAdditional instructions from AGENTS.md:\n#{File.read('AGENTS.md')}" if File.exist?('AGENTS.md')

  unless skills.empty?
    system_prompt += "\n\nThe following skills are available:\n"
    skills.each_value do |skill|
      system_prompt += "<skill><name>#{skill.name}</name><description>#{skill.description}</description></skill>\n"
    end
  end

  tools = Tool.declarations(format: PROVIDER.tool_format)

  response = Terminal.with_spinner do
    PROVIDER.generate_content(messages, tools, system_prompt: system_prompt)
  end

  parsed_response = PROVIDER.parse_response(response)

  extra_parts = parsed_response[:extra_parts] || []

  case parsed_response[:type]
  when :message
    messages << Message.new('model', extra_parts + [{ text: parsed_response[:data] }])
    Terminal.print_assistant(parsed_response[:data])
    has_unsent_tool_results = false
  when :tool_calls
    model_parts = extra_parts + parsed_response[:data].map do |call|
      { function_call: { name: call[:name], args: call[:args], id: call[:id] } }
    end
    messages << Message.new('model', model_parts)

    tool_results = parsed_response[:data].map do |call|
      tool_class = Tool.find(call[:name])
      Terminal.print_tool_execution(tool_class.render_execution(call[:args]))
      result = Tool.call(call[:name], call[:args])
      Terminal.print_tool_preview(call[:name], result)
      { function_response: { name: call[:name], result: result, id: call[:id] } }
    end
    messages << Message.new('tool', tool_results)
    has_unsent_tool_results = true
  when :error
    Terminal.print_error(parsed_response[:data], raw: response.inspect)
    has_unsent_tool_results = false
  end
rescue Interrupt
  puts "\n^C"
  has_unsent_tool_results = false
end
