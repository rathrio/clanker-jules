# frozen_string_literal: true

require_relative 'base_provider'
require 'net/http'
require 'uri'
require 'json'

class GeminiProvider
  include BaseProvider
  # MODEL = 'gemini-flash-latest'
  # MODEL = 'gemini-pro-latest'
  MODEL = 'gemini-2.5-pro'

  def initialize
    @api_key = ENV.fetch('GOOGLE_GENERATIVE_AI_API_KEY')
    @uri = URI("https://generativelanguage.googleapis.com/v1beta/models/#{MODEL}:generateContent?key=#{@api_key}")
  end

  def model = MODEL

  def tool_format
    :gemini
  end

  def generate_content(history, tools, system_prompt: nil)
    http = Net::HTTP.new(@uri.host, @uri.port)
    http.use_ssl = true

    body = {
      contents: Message.format_history(history, format: :gemini),
      tools: [{ functionDeclarations: tools }]
    }

    if system_prompt
      body[:system_instruction] = { parts: [{ text: system_prompt }] }
    end

    request = Net::HTTP::Post.new(@uri)
    request['Content-Type'] = 'application/json'
    request.body = body.to_json

    response = http.request(request)
    JSON.parse(response.body)
  end

  def parse_response(response)
    candidate = response.dig('candidates', 0)
    return { type: :error, data: response.dig('error', 'message') || 'No response from API' } unless candidate

    parts = candidate.dig('content', 'parts') || []

    thinking_parts = parts
      .select { |p| p.key?('thought') || p.key?('thoughtSignature') }
      .map { |p| { _raw_gemini: p } }

    function_calls = parts.select { |p| p.key?('functionCall') }
    unless function_calls.empty?
      tool_calls = function_calls.map do |part|
        fc = part['functionCall']
        { name: fc['name'], args: fc['args'] || {}, id: nil }
      end
      return { type: :tool_calls, data: tool_calls, extra_parts: thinking_parts }
    end

    text_parts = parts.select { |p| p.key?('text') }
    unless text_parts.empty?
      return { type: :message, data: text_parts.map { |p| p['text'] }.join, extra_parts: thinking_parts }
    end

    return { type: :message, data: '', extra_parts: thinking_parts } unless thinking_parts.empty?

    { type: :error, data: 'Unknown response format' }
  end
end
