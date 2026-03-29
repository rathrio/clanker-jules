# frozen_string_literal: true

require 'json'

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
    query = params.fetch('query').to_s.strip
    return 'Query cannot be empty.' if query.empty?

    result_or_error = lookup_memory(query)
    return result_or_error if result_or_error.is_a?(String)

    format_pair(result_or_error[:user], result_or_error[:model], result_or_error[:file])
  rescue StandardError => e
    "An unexpected error occurred: #{e.message}"
  end

  private

  def lookup_memory(query)
    chats_dir = File.expand_path('~/.jules/chats')
    return 'Memory directory does not exist.' unless Dir.exist?(chats_dir)

    chat_files = chat_files_by_recency(chats_dir)
    return "No memory found for '#{query}'." if chat_files.empty?

    result = if recency_query?(query)
               find_latest_pair(chat_files)
             else
               find_best_matching_pair(chat_files, query)
             end

    result || "No memory found for '#{query}'."
  end

  def chat_files_by_recency(chats_dir)
    Dir.glob(File.join(chats_dir, '*.json')).sort_by { |file| File.mtime(file) }.reverse
  end

  def recency_query?(query)
    recency_keywords = %w[last latest recent previous]
    recency_keywords.any? { |keyword| query.downcase.include?(keyword) }
  end

  def find_latest_pair(files)
    files.each do |file|
      messages = parse_chat(file)
      next unless messages

      pair = extract_pairs(messages).last
      next unless pair

      return { user: pair[:user], model: pair[:model], file: file }
    end

    nil
  end

  def find_best_matching_pair(files, query)
    best = nil

    files.each do |file|
      messages = parse_chat(file)
      next unless messages

      pairs = extract_pairs(messages)
      next if pairs.empty?

      pairs.each do |pair|
        score = score_pair(pair, query)
        next if score <= 0

        candidate = { user: pair[:user], model: pair[:model], file: file, score: score, mtime: File.mtime(file) }
        best = better_candidate(best, candidate)
      end
    end

    best
  end

  def better_candidate(current, candidate)
    return candidate unless current
    return candidate if candidate[:score] > current[:score]
    return candidate if candidate[:score] == current[:score] && candidate[:mtime] > current[:mtime]

    current
  end

  def parse_chat(file)
    content = File.read(file)
    parsed = JSON.parse(content)
    parsed.is_a?(Array) ? parsed : nil
  rescue JSON::ParserError
    nil
  end

  def extract_pairs(messages)
    pairs = []
    pending_user = nil

    messages.each do |message|
      role = message['role']

      if role == 'user' && user_text_message?(message)
        pending_user = message
      elsif role == 'model' && model_text_message?(message) && pending_user
        pairs << { user: pending_user, model: message }
      end
    end

    pairs
  end

  def user_text_message?(message)
    !extract_display_text(message).strip.empty?
  end

  def model_text_message?(message)
    !extract_display_text(message).strip.empty?
  end

  def score_pair(pair, query)
    combined_text = [extract_search_text(pair[:user]), extract_search_text(pair[:model])].join(' ').downcase
    return 0 if combined_text.empty?

    terms = query_terms(query)
    return 0 if terms.empty?

    terms.sum { |term| combined_text.include?(term) ? 1 : 0 }
  end

  def query_terms(query)
    query.downcase
         .scan(/[a-z0-9_-]+/)
         .uniq
         .reject { |term| term.length < 3 }
  end

  def extract_display_text(message)
    parts = message['parts'] || []
    parts.filter_map { |part| part.is_a?(Hash) ? part['text'] : nil }.join(' ')
  end

  def extract_search_text(message)
    parts = message['parts'] || []
    parts.map { |part| search_text_for_part(part) }.join(' ')
  end

  def search_text_for_part(part)
    return part if part.is_a?(String)
    return '' unless part.is_a?(Hash)

    return part['text'].to_s if part['text']

    function_call_text(part) || function_response_text(part) || ''
  end

  def function_call_text(part)
    function_call = part['functionCall']
    return nil unless function_call

    [function_call['name'], function_call['args'].to_s].join(' ')
  end

  def function_response_text(part)
    function_response = part['functionResponse']
    return nil unless function_response

    response = function_response['response'] || {}
    [function_response['name'], response['result'].to_s].join(' ')
  end

  def format_pair(user_message, model_message, filename)
    "[From #{File.basename(filename)}]\nUSER: #{extract_display_text(user_message)}\nMODEL: #{extract_display_text(model_message)}"
  end
end
