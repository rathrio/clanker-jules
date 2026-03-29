require 'json'
require 'net/http'
require 'uri'

require_relative 'message'
require_relative 'tool'

# GEMINI_MODEL = 'gemini-flash-latest'
GEMINI_MODEL = 'gemini-pro-latest'
API_KEY = ENV.fetch('GOOGLE_GENERATIVE_AI_API_KEY')
URL = URI("https://generativelanguage.googleapis.com/v1beta/models/#{GEMINI_MODEL}:generateContent?key=#{API_KEY}")
HTTP = Net::HTTP.new(URL.host, URL.port)
HTTP.use_ssl = true

messages = []
has_unsent_tool_results = false

loop do
  begin
    if !has_unsent_tool_results
      print "you: "
      input = gets
      exit if input.nil?
      input = input.chomp # get text from stdin
      if input.strip =~ /^(quit|exit)/
        exit
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

    request = Net::HTTP::Post.new(URL)
    has_unsent_tool_results = false

    request["Content-Type"] = "application/json"
    request.body = body.to_json
    response = HTTP.request(request)
    parsed = JSON.parse(response.body)

    candidate = parsed['candidates']&.first
    if candidate.nil?
      puts "got this back from api: #{parsed}"
      raise 'no candidates'
    end

    parts = candidate.dig('content', 'parts')
    next if parts.nil?

    parts.each do |part|
      case
      when text = part['text']
        puts "jules: #{text}"
        messages << Message.new('model', [{ text: }])
      when call = part['functionCall']
        puts "jules: Executing tool: #{call['name']} with args: #{call['args']}"
        result = Tool.call(call['name'], call['args'])
        messages << Message.new('model', [part])
        messages << Message.new('user', [{ functionResponse: { name: call['name'], response: { result: } } }])
        has_unsent_tool_results = true
      else
        puts "jules: Error: Unknown part received: #{part.inspect}"
      end
    end
  rescue Interrupt
    puts "\n^C"
    has_unsent_tool_results = false
  end
end
