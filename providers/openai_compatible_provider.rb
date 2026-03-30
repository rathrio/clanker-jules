# frozen_string_literal: true

require_relative '../provider'
require 'net/http'
require 'uri'
require 'json'

class OpenAICompatibleProvider
  include Provider

  register_provider 'openai-compatible'
  register_provider 'openai_compatible'
  register_provider 'openrouter', preset: :openrouter
  register_provider 'kiro', preset: :kiro

  OPENAI_COMPATIBLE_DEFAULTS = {
    provider_label: 'OpenRouter',
    base_url: 'https://openrouter.ai/api/v1/chat/completions',
    api_key_env: 'OPENROUTER_API_KEY',
    default_model: 'qwen/qwen3-coder-flash',
    max_tokens: 4096
  }.freeze

  KIRO_DEFAULTS = {
    provider_label: 'Kiro',
    base_url: ENV.fetch('KIRO_BASE_URL', 'http://localhost:41929/v1/chat/completions'),
    api_key_env: 'KIRO_API_KEY',
    api_key_fallback: 'kiro-local-proxy',
    default_model: 'claude-opus-4.6',
    max_tokens: 128_000
  }.freeze

  def initialize(model: nil, preset: nil, base_url: nil, api_key: nil, max_tokens: nil)
    defaults = preset == :kiro ? KIRO_DEFAULTS : OPENAI_COMPATIBLE_DEFAULTS

    @provider_label = defaults[:provider_label]
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

  attr_reader :model, :provider_label

  def tool_format
    :openai
  end

  NETWORK_ERRORS = [
    Net::OpenTimeout,
    Net::ReadTimeout,
    Timeout::Error,
    Errno::ECONNRESET,
    Errno::ECONNREFUSED,
    EOFError,
    SocketError,
    IOError
  ].freeze

  DEFAULT_OPEN_TIMEOUT = 10
  DEFAULT_READ_TIMEOUT = 300
  DEFAULT_RETRIES = 2

  def generate_content(history, tools, system_prompt: nil)
    messages = Message.format_history(history, format: :openai)
    messages.unshift({ role: 'system', content: system_prompt }) if system_prompt

    request = Net::HTTP::Post.new(@uri.request_uri, @headers)
    request.body = {
      model: @model,
      max_tokens: @max_tokens,
      messages: messages,
      tools: tools
    }.to_json

    retries_left = DEFAULT_RETRIES

    begin
      http = Net::HTTP.new(@uri.host, @uri.port)
      http.use_ssl = @uri.scheme == 'https'
      http.open_timeout = DEFAULT_OPEN_TIMEOUT
      http.read_timeout = DEFAULT_READ_TIMEOUT

      response = http.request(request)
      JSON.parse(response.body)
    rescue *NETWORK_ERRORS => e
      retries_left -= 1
      return { 'error' => { 'message' => "#{@provider_label} network error: #{e.class} - #{e.message}" } } if retries_left.negative?

      sleep(0.25 * (DEFAULT_RETRIES - retries_left))
      retry
    rescue JSON::ParserError => e
      { 'error' => { 'message' => "Invalid JSON response from #{@provider_label}: #{e.message}" } }
    end
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

  def list_models
    models_uri = URI.parse("#{@uri.scheme}://#{@uri.host}/api/v1/models")
    request = Net::HTTP::Get.new(models_uri.request_uri, @headers)

    retries_left = DEFAULT_RETRIES

    begin
      http = Net::HTTP.new(models_uri.host, models_uri.port)
      http.use_ssl = models_uri.scheme == 'https'
      http.open_timeout = DEFAULT_OPEN_TIMEOUT
      http.read_timeout = DEFAULT_READ_TIMEOUT

      response = http.request(request)
      parsed = JSON.parse(response.body)

      data = parsed['data']
      return data if data.is_a?(Array)

      []
    rescue *NETWORK_ERRORS => e
      retries_left -= 1
      return { error: "#{@provider_label} network error: #{e.class} - #{e.message}" } if retries_left.negative?

      sleep(0.25 * (DEFAULT_RETRIES - retries_left))
      retry
    rescue JSON::ParserError => e
      { error: "Invalid JSON response from #{@provider_label}: #{e.message}" }
    end
  end
end
