#!/usr/bin/env ruby
require 'json'
require 'readline'

require_relative 'message'
require_relative 'tool'
require_relative 'gemini_client'

module UI
  PINK   = "\e[38;2;255;121;198m"
  PURPLE = "\e[38;2;189;147;249m"
  CYAN   = "\e[38;2;139;233;253m"
  GREEN  = "\e[38;2;80;250;123m"
  ORANGE = "\e[38;2;255;184;108m"
  RED    = "\e[38;2;255;85;85m"
  YELLOW = "\e[38;2;241;250;140m"
  COMMENT= "\e[38;2;98;114;164m"
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
has_unsent_tool_results = false

loop do
  begin
    if !has_unsent_tool_results
      input = Readline.readline(UI.user_prompt, true)
      exit if input.nil?
      input = input.strip

      next if input.empty?

      if input =~ /^(quit|exit)$/i || input == '/quit' || input == '/exit'
        exit
      elsif input == '/help'
        puts "#{UI::CYAN}Commands:"
        puts "  /clear - Clear the conversation history"
        puts "  /multi - Enter multiline mode (for pasting code or writing paragraphs). End with Ctrl+D."
        puts "  /help  - Show this help message"
        puts "  /exit  - Exit the assistant#{UI::RESET}"
        next
      elsif input == '/clear'
        messages = []
        puts "#{UI::CYAN}Conversation cleared.#{UI::RESET}"
        next
      elsif input == '/multi'
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

      messages << Message.new('user', [{ text: input }])
    end

    File.write('raw-messages.json', messages.map(&:as_gemini).to_json)

    system_text = 'You are Jules, a straight and to-the-point general-purpose terminal assistant.'
    if File.exist?('AGENTS.md')
      system_text += "\n\nAdditional instructions from AGENTS.md:\n" + File.read('AGENTS.md')
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
      case
      when text = part['text']
        unless jules_label_printed
          puts "#{UI::PURPLE}#{UI::BOLD}jules:#{UI::RESET}"
          jules_label_printed = true
        end
        puts text
      when call = part['functionCall']
        tool_class = Tool.find(call['name'])
        puts "#{UI::COMMENT}#{tool_class.render_execution(call['args'])}#{UI::RESET}"
        result = Tool.call(call['name'], call['args'])
        tool_response_parts << { functionResponse: { name: call['name'], response: { result: } } }
      when part.key?('thought') || part.key?('thoughtSignature')
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
end
