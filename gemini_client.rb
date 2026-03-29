# frozen_string_literal: true

require 'json'
require 'net/http'
require 'uri'

class GeminiClient
  # GEMINI_MODEL = 'gemini-flash-latest'
  # GEMINI_MODEL = 'gemini-pro-latest'
  GEMINI_MODEL = 'gemini-2.5-pro'

  def initialize
    @api_key = ENV.fetch('GOOGLE_GENERATIVE_AI_API_KEY')
    @url = URI("https://generativelanguage.googleapis.com/v1beta/models/#{GEMINI_MODEL}:generateContent?key=#{@api_key}")
    @http = Net::HTTP.new(@url.host, @url.port)
    @http.use_ssl = true
  end

  def generate_content(body)
    request = Net::HTTP::Post.new(@url)
    request['Content-Type'] = 'application/json'
    request.body = body.to_json

    response = @http.request(request)
    JSON.parse(response.body)
  end
end
