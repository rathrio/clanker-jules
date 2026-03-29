# frozen_string_literal: true

require_relative 'base_provider'
require 'net/http'
require 'uri'
require 'json'

class OpenRouterProvider
  include Provider
  # MODEL = 'openai/gpt-4o'
  MODEL = 'qwen/qwen3-coder'
  # MODEL = 'anthropic/claude-3-haiku'

  def initialize
    api_key = ENV.fetch('OPENROUTER_API_KEY')
    @uri = URI.parse('https://openrouter.ai/api/v1/chat/completions')
    @headers = {
      'Content-Type' => 'application/json',
      'Authorization' => "Bearer #{api_key}"
    }
  end

  def model = MODEL

  def tool_format
    :openai
  end

  def generate_content(history, tools, system_prompt: nil)
    http = Net::HTTP.new(@uri.host, @uri.port)
    http.use_ssl = true

    messages = Message.format_history(history, format: :openai)
    messages.unshift({ role: 'system', content: system_prompt }) if system_prompt

    request = Net::HTTP::Post.new(@uri.request_uri, @headers)
    request.body = {
      model: MODEL,
      max_tokens: 4096,
      messages: messages,
      tools: tools
    }.to_json

    response = http.request(request)
    JSON.parse(response.body)
  end

  def parse_response(response)
    message = response.dig('choices', 0, 'message')
    return { type: :error, data: response.dig('error', 'message') || 'No response from API' } unless message

    if (calls = message['tool_calls'])
      tool_calls = calls.map do |call|
        {
          name: call.dig('function', 'name'),
          args: JSON.parse(call.dig('function', 'arguments')),
          id: call['id']
        }
      end
      return { type: :tool_calls, data: tool_calls, extra_parts: [] }
    end

    if (text = message['content'])
      return { type: :message, data: text, extra_parts: [] }
    end

    { type: :error, data: 'Unknown response format' }
  end
end
