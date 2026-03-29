require 'json'
require 'net/http'
require 'uri'

GEMINI_MODEL = 'gemini-2.5-flash'
API_KEY = ENV.fetch('GOOGLE_GENERATIVE_AI_API_KEY')
URL = URI("https://generativelanguage.googleapis.com/v1beta/models/#{GEMINI_MODEL}:generateContent?key=#{API_KEY}")
HTTP = Net::HTTP.new(URL.host, URL.port)
HTTP.use_ssl = true

TOOLS = {
  read_file: {
    declaration: {
      name: 'read_file',
      description: 'Read the contents of a file at the given path',
      parameters: {
        type: 'object',
        properties: {
          path: { type: 'string', description: 'The path to the file to read' }
        },
        required: ['path']
      }
    },
    execute: -> (args) {
      File.read(args.fetch('path'))
    }
  },
  write_file: {
    declaration: {
      name: 'write_file',
      description: 'Write content to a file at the given path. Creates the file if it does not exist, or overwrites it if it does.',
      parameters: {
        type: 'object',
        properties: {
          path: { type: 'string', description: 'The path to the file to write' },
          content: { type: 'string', description: 'The content to write to the file' }
        },
        required: ['path', 'content']
      }
    },
    execute: -> (args) {
      File.write(args.fetch('path'), args.fetch('content'))
      args.fetch('path')
    }
  }
}

TOOL_DECLARATIONS = TOOLS.values.map { |v| v[:declaration] }

messages = []
has_unsent_tool_results = false

loop do
  if !has_unsent_tool_results
    print "you: "
    input = gets.chomp # get text from stdin
    if input.strip =~ /^(quit|exit)/
      exit
    end
    messages << { role: 'user', parts: [{ text: input }] }
  end

  File.write('raw-messages.json', messages.to_json)

  body = {
    system_instruction: {
      parts: [{
        text: 'You are Jules, a straight and to-the-point general-purpose terminal assistant. You talk like the character Jules from Pulp Fiction. You are not polite.'
      }]
    },
    contents: messages,
    tools: [{ function_declarations: TOOL_DECLARATIONS }]
  }

  request = Net::HTTP::Post.new(URL)
  has_unsent_tool_results = false

  request["Content-Type"] = "application/json"
  request.body = body.to_json
  response = HTTP.request(request)
  parsed = JSON.parse(response.body)

  candidate = parsed['candidates']&.first
  raise 'no candidates' if candidate.nil?

  parts = candidate.dig('content', 'parts')
  parts.each do |part|
    if (text = part['text'])
      puts "jules: #{text}"
      messages << { role: 'model', parts: [{ text: }] }
    end

    if (call = part['functionCall'])
      result = TOOLS.fetch(call['name'].to_sym)[:execute].call(call['args'])
      messages << { role: 'model', parts: [part.slice('functionCall')] }
      messages << { role: 'user', parts: [{ functionResponse: { name: call['name'], response: { result: } } }] }
      has_unsent_tool_results = true
    end
  end
end
