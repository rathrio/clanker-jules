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
      self.model = model || DEFAULT_MODEL
    end

    attr_reader :model

    def model=(value)
      @model = normalize_model_id(value)
    end

    def tool_format
      :gemini
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

    def generate_content(history, tools, system_prompt: nil)
      uri = URI("https://generativelanguage.googleapis.com/v1beta/models/#{@model}:generateContent?key=#{@api_key}")

      http = Net::HTTP.new(uri.host, uri.port)
      http.use_ssl = true
      http.open_timeout = DEFAULT_OPEN_TIMEOUT
      http.read_timeout = DEFAULT_READ_TIMEOUT

      body = {
        contents: Jules::Message.format_history(history, format: :gemini),
        tools: [{ functionDeclarations: tools }]
      }

      body[:system_instruction] = { parts: [{ text: system_prompt }] } if system_prompt

      request = Net::HTTP::Post.new(uri)
      request['Content-Type'] = 'application/json'
      request.body = body.to_json

      response = http.request(request)
      Jules::Result.ok(JSON.parse(response.body))
    rescue *NETWORK_ERRORS => e
      Jules::Result.err(
        code: 'provider_network_error',
        message: "Gemini network error: #{e.class} - #{e.message}",
        detail: { provider: provider_label, error_class: e.class.to_s }
      )
    rescue JSON::ParserError => e
      Jules::Result.err(
        code: 'provider_parse_error',
        message: "Invalid JSON response from Gemini: #{e.message}",
        detail: { provider: provider_label }
      )
    end

    def parse_response(response)
      candidate = response.dig('candidates', 0)
      unless candidate
        return Jules::Result.err(
          code: 'provider_response_error',
          message: response.dig('error', 'message') || 'No response from API',
          detail: { provider: provider_label }
        )
      end

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
        return Jules::Result.ok({ type: :tool_calls, data: tool_calls, extra_parts: thinking_parts })
      end

      text_parts = parts.select { |p| p.key?('text') }
      unless text_parts.empty?
        return Jules::Result.ok({
                                  type: :message,
                                  data: text_parts.map { |p| p['text'] }.join,
                                  extra_parts: thinking_parts
                                })
      end

      if thinking_parts.any?
        finish_reason = candidate['finishReason']
        message = 'Gemini returned only thinking parts with no text or tool calls'
        message = "#{message} (finishReason: #{finish_reason})" if finish_reason

        return Jules::Result.err(
          code: 'provider_response_error',
          message: message,
          detail: { provider: provider_label, finish_reason: finish_reason }
        )
      end

      Jules::Result.err(
        code: 'provider_response_error',
        message: 'Unknown response format',
        detail: { provider: provider_label }
      )
    end

    def list_models
      uri = URI("https://generativelanguage.googleapis.com/v1beta/models?key=#{@api_key}")

      http = Net::HTTP.new(uri.host, uri.port)
      http.use_ssl = true
      http.open_timeout = DEFAULT_OPEN_TIMEOUT
      http.read_timeout = DEFAULT_READ_TIMEOUT

      request = Net::HTTP::Get.new(uri)
      response = http.request(request)
      parsed = JSON.parse(response.body)

      return Jules::Result.ok(parsed['models']) if parsed['models'].is_a?(Array)

      Jules::Result.ok([])
    rescue JSON::ParserError => e
      Jules::Result.err(
        code: 'provider_parse_error',
        message: "Invalid JSON response from Gemini: #{e.message}",
        detail: { provider: provider_label }
      )
    rescue *NETWORK_ERRORS => e
      Jules::Result.err(
        code: 'provider_network_error',
        message: "Gemini network error: #{e.class} - #{e.message}",
        detail: { provider: provider_label, error_class: e.class.to_s }
      )
    end

    private

    def normalize_model_id(value)
      model_id = value.to_s.strip
      model_id = model_id.sub(%r{\Amodels/}, '')
      model_id.empty? ? DEFAULT_MODEL : model_id
    end
  end
end
