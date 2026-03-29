# frozen_string_literal: true

require 'json'
require 'shellwords'

class MemoryTool
  include Tool

  def self.description
    'Searches past conversations for a specific topic and returns the most relevant exchange(s). Use this when the user refers to something not in the current active chat.'
  end

  param name: 'query',
        type: String,
        description: 'The keywords or topic to search for.'

  def call(params)
    chats_dir = File.expand_path('~/.jules/chats')
    return 'Memory directory does not exist.' unless Dir.exist?(chats_dir)

    escaped_query = Shellwords.escape(params.fetch('query'))
    # Grep for files containing the query, sort by modification time (newest first), and take the most recent.
    search_command = "grep -l -i -r #{escaped_query} #{Shellwords.escape(chats_dir)} | xargs -r ls -t | head -n 1"
    most_recent_file = `#{search_command}`.strip

    return "No memory found matching '#{params.fetch('query')}'." if most_recent_file.empty?

    begin
      content = File.read(most_recent_file)
      messages = JSON.parse(content)

      # Find the index of the first message part that includes the query
      found_index = messages.find_index do |message|
        message['parts'].any? { |part| part.is_a?(String) && part.downcase.include?(params.fetch('query').downcase) }
      end

      return "Query found in #{File.basename(most_recent_file)}, but could not extract a conversational pair." unless found_index

      # Extract the relevant pair
      user_message = nil
      model_message = nil

      if messages[found_index]['role'] == 'user' && messages[found_index + 1] && messages[found_index + 1]['role'] == 'model'
        user_message = messages[found_index]
        model_message = messages[found_index + 1]
      elsif messages[found_index]['role'] == 'model' && found_index.positive? && messages[found_index - 1]['role'] == 'user'
        user_message = messages[found_index - 1]
        model_message = messages[found_index]
      else
        # If we found a match but it's not a clear user/model pair, return just that message.
        single_message = messages[found_index]
        return "[From #{File.basename(most_recent_file)}]\n#{single_message['role'].upcase}: #{get_text(single_message)}"
      end

      format_pair(user_message, model_message, most_recent_file)
    rescue JSON::ParserError
      "Error parsing memory file: #{File.basename(most_recent_file)}"
    rescue StandardError => e
      "An unexpected error occurred: #{e.message}"
    end
  end

  private

  def get_text(message)
    message['parts'].map { |part| part.is_a?(Hash) ? (part['text'] || '') : part.to_s }.join(' ')
  end

  def format_pair(user_message, model_message, filename)
    "[From #{File.basename(filename)}]\nUSER: #{get_text(user_message)}\nMODEL: #{get_text(model_message)}"
  end
end
