# frozen_string_literal: true

require_relative 'provider'
require 'net/http'
require 'uri'
require 'json'

class OpenRouterProvider
  include Provider

  OPENROUTER_DEFAULTS = {
    base_url: 'https://openrouter.ai/api/v1/chat/completions',
    api_key_env: 'OPENROUTER_API_KEY',
    default_model: 'openai/gpt-5.3-codex',
    max_tokens: 4096
  }.freeze

  KIRO_DEFAULTS = {
    base_url: ENV.fetch('KIRO_BASE_URL', 'http://localhost:41929/v1/chat/completions'),
    api_key_env: 'KIRO_API_KEY',
    api_key_fallback: 'kiro-local-proxy',
    default_model: 'claude-opus-4.6',
    max_tokens: 128_000
  }.freeze

  def initialize(model: nil, preset: nil, base_url: nil, api_key: nil, max_tokens: nil)
    defaults = preset == :kiro ? KIRO_DEFAULTS : OPENROUTER_DEFAULTS

    @uri = URI.parse(base_url || defaults[:base_url])
    @model = model || defaults[:default_model]
    @max_tokens = max_tokens || defaults[:max_tokens]

    resolved_key = api_key ||
                   ENV[defaults[:api_key_env]] ||
                   defaults[:api_key_fallback] ||
                   (raise KeyError, "Missing API key: set #{defaults[:api_key_env]}")

    @headers = {
      'Content-Type' => 'application/json',
      'Authorization' => "Bearer #{resolved_key}"
    }
  end

  attr_reader :model

  def tool_format
    :openai
  end

  def generate_content(history, tools, system_prompt: nil)
    http = Net::HTTP.new(@uri.host, @uri.port)
    http.use_ssl = @uri.scheme == 'https'

    messages = Message.format_history(history, format: :openai)
    messages.unshift({ role: 'system', content: system_prompt }) if system_prompt

    request = Net::HTTP::Post.new(@uri.request_uri, @headers)
    request.body = {
      model: @model,
      max_tokens: @max_tokens,
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
