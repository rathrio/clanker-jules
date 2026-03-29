require 'json'
require 'net/http'
require 'uri'

require_relative 'message'
require_relative 'tool'

GEMINI_MODEL = 'gemini-flash-latest'
API_KEY = ENV.fetch('GOOGLE_GENERATIVE_AI_API_KEY')
URL = URI("https://generativelanguage.googleapis.com/v1beta/models/#{GEMINI_MODEL}:generateContent?key=#{API_KEY}")
HTTP = Net::HTTP.new(URL.host, URL.port)
HTTP.use_ssl = true

messages = []
has_unsent_tool_results = false

loop do
  if !has_unsent_tool_results
    print "you: "
    input = gets.chomp # get text from stdin
    if input.strip =~ /^(quit|exit)/
      exit
    end
    messages << Message.new('user', [{ text: input }])
  end

  File.write('raw-messages.json', messages.to_json)

  body = {
    system_instruction: {
      parts: [{
        text: 'You are Jules, a straight and to-the-point general-purpose terminal assistant.'
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
    if (text = part['text'])
      puts "jules: #{text}"
      messages << Message.new('model', [{ text: }])
    end

    if (call = part['functionCall'])
      puts "jules: Executing tool: #{call['name']} with args: #{call['args']}"
      result = Tool.call(call['name'], call['args'])
      messages << Message.new('user', [part.slice('functionCall')])
      messages << Message.new('user', [{ functionResponse: { name: call['name'], response: { result: } } }])
      has_unsent_tool_results = true
    end
  end
end
