# frozen_string_literal: true

require 'json'
require 'shellwords'

class MemoryTool
  include Tool

  def self.description
    'Searches past conversations for a specific topic and returns the most relevant exchange(s). Use this when the user refers to something not in the current active chat.'
  end

  def self.render_execution(args)
    "Searching memory for: \"#{args['query']}\""
  end

  param name: 'query',
        type: String,
        description: 'The keywords or topic to search for.'

  def call(params)
    chats_dir = File.expand_path('~/.jules/chats')
    return 'Memory directory does not exist.' unless Dir.exist?(chats_dir)

    query = params.fetch('query')
    recency_keywords = ['last', 'latest', 'recent', 'previous']
    is_recency_query = recency_keywords.any? { |keyword| query.downcase.include?(keyword) }

    most_recent_file = if is_recency_query
                         # For recency queries, find the newest file directly.
                         Dir.glob(File.join(chats_dir, '*')).max_by { |f| File.mtime(f) }
                       else
                         # For other queries, use the existing grep logic.
                         escaped_query = Shellwords.escape(query)
                         search_command = "grep -l -i -r #{escaped_query} #{Shellwords.escape(chats_dir)} | xargs -r ls -t | head -n 1"
                         `#{search_command}`.strip
                       end

    return "No memory found for '#{query}'." if most_recent_file.nil? || most_recent_file.empty?

    begin
      content = File.read(most_recent_file)
      messages = JSON.parse(content)

      user_message, model_message = find_relevant_messages(messages, query, is_recency_query)

      return "Query found in #{File.basename(most_recent_file)}, but could not extract a conversational pair." unless user_message && model_message

      format_pair(user_message, model_message, most_recent_file)
    rescue JSON::ParserError
      "Error parsing memory file: #{File.basename(most_recent_file)}"
    rescue StandardError => e
      "An unexpected error occurred: #{e.message}"
    end
  end

  private

  def find_relevant_messages(messages, query, is_recency_query)
    if is_recency_query
      # Return the last user/model pair from the file.
      model_idx = messages.rindex { |m| m['role'] == 'model' }
      return nil unless model_idx&.positive? && messages[model_idx - 1]['role'] == 'user'

      return messages[model_idx - 1], messages[model_idx]
    else
      # Use existing logic to find the query in the file.
      found_index = messages.find_index do |message|
        message['parts'].any? { |part| part.is_a?(String) && part.downcase.include?(query.downcase) }
      end
      return nil unless found_index

      if messages[found_index]['role'] == 'user' && messages[found_index + 1]&.[]('role') == 'model'
        return messages[found_index], messages[found_index + 1]
      elsif messages[found_index]['role'] == 'model' && found_index.positive? && messages[found_index - 1]['role'] == 'user'
        return messages[found_index - 1], messages[found_index]
      end
    end
    nil
  end

  def get_text(message)
    message['parts'].map { |part| part.is_a?(Hash) ? (part['text'] || '') : part.to_s }.join(' ')
  end

  def format_pair(user_message, model_message, filename)
    "[From #{File.basename(filename)}]\nUSER: #{get_text(user_message)}\nMODEL: #{get_text(model_message)}"
  end
end
