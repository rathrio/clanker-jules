# frozen_string_literal: true

class WebfetchTool
  include Tool

  def self.description
    'Fetch the contents of a webpage and return it as clean Markdown'
  end

  def self.render_execution(args)
    "Fetching webpage: #{args['url']}"
  end

  param name: 'url', type: String, description: 'The URL of the webpage to fetch'
  def call(params)
    require 'net/http'
    require 'uri'

    url = params.fetch('url')
    jina_url = URI("https://r.jina.ai/#{url}")

    begin
      response = Net::HTTP.get_response(jina_url)

      if response.is_a?(Net::HTTPSuccess)
        response.body
      else
        "Error: Failed to fetch webpage. HTTP Status: #{response.code}"
      end
    rescue StandardError => e
      "Error fetching webpage: #{e.message}"
    end
  end
end
