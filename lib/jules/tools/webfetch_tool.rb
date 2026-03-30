# frozen_string_literal: true

module Jules
  class WebfetchTool
    include Tool

    def self.description
      <<~DESC.chomp
        Fetch a webpage and return its contents as clean Markdown.

        Use this tool when you:
        - Need to read documentation, API references, or guides from a URL
        - The user shares a link and wants you to read or summarize it
        - Need to check external resources (changelogs, issue pages, Stack Overflow answers)
      DESC
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
          response.body.force_encoding('UTF-8')
        else
          "Error: Failed to fetch webpage. HTTP Status: #{response.code}"
        end
      rescue StandardError => e
        "Error fetching webpage: #{e.message}"
      end
    end
  end
end
