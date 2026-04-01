# frozen_string_literal: true

require_relative '../provider'
require 'net/http'
require 'uri'
require 'json'

module Jules
  class GeminiProvider
    include Provider

    DEFAULT_MODEL = 'gemini-flash-latest'
    # DEFAULT_MODEL = 'gemini-pro-latest'
    # DEFAULT_MODEL = 'gemini-2.5-pro'

    def initialize(model: nil)
      @api_key = ENV.fetch('GOOGLE_GENERATIVE_AI_API_KEY')
      @model = model || DEFAULT_MODEL
    end

    attr_accessor :model

    def tool_format
      :gemini
    end

    def generate_content(history, tools, system_prompt: nil)
      uri = URI("https://generativelanguage.googleapis.com/v1beta/models/#{@model}:generateContent?key=#{@api_key}")

      http = Net::HTTP.new(uri.host, uri.port)
      http.use_ssl = true

      body = {
        contents: Jules::Message.format_history(history, format: :gemini),
        tools: [{ functionDeclarations: tools }]
      }

      body[:system_instruction] = { parts: [{ text: system_prompt }] } if system_prompt

      request = Net::HTTP::Post.new(uri)
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
      return { type: :message, data: text_parts.map { |p| p['text'] }.join, extra_parts: thinking_parts } unless text_parts.empty?

      return { type: :message, data: '', extra_parts: thinking_parts } unless thinking_parts.empty?

      { type: :error, data: 'Unknown response format' }
    end

    def list_models
      uri = URI("https://generativelanguage.googleapis.com/v1beta/models?key=#{@api_key}")

      http = Net::HTTP.new(uri.host, uri.port)
      http.use_ssl = true

      request = Net::HTTP::Get.new(uri)
      response = http.request(request)
      parsed = JSON.parse(response.body)

      return parsed['models'] if parsed['models'].is_a?(Array)

      []
    rescue JSON::ParserError => e
      { error: "Invalid JSON response from Gemini: #{e.message}" }
    rescue StandardError => e
      { error: "Gemini network error: #{e.class} - #{e.message}" }
    end
  end
end
