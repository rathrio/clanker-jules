# frozen_string_literal: true

require_relative '../test_helper'
require 'json'

class MemoryToolTest < Minitest::Test
  def test_returns_error_for_empty_query
    result = Jules::MemoryTool.new.call('query' => '  ')

    assert_equal 'Query cannot be empty.', result
  end

  def test_returns_directory_missing_when_chat_store_does_not_exist
    with_temp_home do
      result = Jules::MemoryTool.new.call('query' => 'deploy issue')

      assert_equal 'Memory directory does not exist.', result
    end
  end

  def test_returns_latest_user_model_pair_for_recency_queries
    with_temp_home do |home|
      chats_dir = File.join(home, '.jules', 'chats')
      FileUtils.mkdir_p(chats_dir)

      older = File.join(chats_dir, 'older.json')
      newer = File.join(chats_dir, 'newer.json')

      write_chat(older, 'old question', 'old answer')
      write_chat(newer, 'new question', 'new answer')
      File.utime(Time.now - 60, Time.now - 60, older)
      File.utime(Time.now, Time.now, newer)

      result = Jules::MemoryTool.new.call('query' => 'latest')

      assert_includes result, '[From newer.json]'
      assert_includes result, 'USER: new question'
      assert_includes result, 'MODEL: new answer'
    end
  end

  def test_returns_best_matching_pair_for_keyword_queries
    with_temp_home do |home|
      chats_dir = File.join(home, '.jules', 'chats')
      FileUtils.mkdir_p(chats_dir)

      deploy = File.join(chats_dir, 'deploy.json')
      unrelated = File.join(chats_dir, 'misc.json')

      write_chat(deploy, 'Our deploy fails in production', 'Use rollback and clear cache')
      write_chat(unrelated, 'What is your favorite color?', 'Blue')

      result = Jules::MemoryTool.new.call('query' => 'deploy production rollback')

      assert_includes result, '[From deploy.json]'
      assert_includes result, 'USER: Our deploy fails in production'
      assert_includes result, 'MODEL: Use rollback and clear cache'
    end
  end

  def test_tiebreak_prefers_more_recently_modified_chat_when_scores_are_equal
    with_temp_home do |home|
      chats_dir = File.join(home, '.jules', 'chats')
      FileUtils.mkdir_p(chats_dir)

      older = File.join(chats_dir, 'older.json')
      newer = File.join(chats_dir, 'newer.json')

      write_chat(older, 'deploy rollback cache', 'older answer')
      write_chat(newer, 'deploy rollback cache', 'newer answer')
      File.utime(Time.now - 3600, Time.now - 3600, older)
      File.utime(Time.now, Time.now, newer)

      result = Jules::MemoryTool.new.call('query' => 'deploy rollback cache')

      assert_includes result, '[From newer.json]'
      assert_includes result, 'MODEL: newer answer'
    end
  end

  def test_ignores_chat_files_with_invalid_json
    with_temp_home do |home|
      chats_dir = File.join(home, '.jules', 'chats')
      FileUtils.mkdir_p(chats_dir)

      File.write(File.join(chats_dir, 'broken.json'), '{not valid json')
      good = File.join(chats_dir, 'good.json')
      write_chat(good, 'deploy production issue', 'check rollback')

      result = Jules::MemoryTool.new.call('query' => 'deploy production')

      assert_includes result, '[From good.json]'
      assert_includes result, 'USER: deploy production issue'
    end
  end

  def test_no_memory_found_when_no_pair_matches_query
    with_temp_home do |home|
      chats_dir = File.join(home, '.jules', 'chats')
      FileUtils.mkdir_p(chats_dir)
      write_chat(File.join(chats_dir, 'a.json'), 'hello world', 'hi there')

      result = Jules::MemoryTool.new.call('query' => 'zzz-nothing-here')

      assert_equal "No memory found for 'zzz-nothing-here'.", result
    end
  end

  def test_returns_error_message_when_chat_file_raises_during_processing
    with_temp_home do |home|
      chats_dir = File.join(home, '.jules', 'chats')
      FileUtils.mkdir_p(chats_dir)
      chat = File.join(chats_dir, 'unreadable.json')
      write_chat(chat, 'hello', 'hi')
      File.chmod(0o000, chat)

      begin
        result = Jules::MemoryTool.new.call('query' => 'hello there')

        assert_match(/An unexpected error occurred:/, result)
      ensure
        File.chmod(0o644, chat)
      end
    end
  end

  def test_function_call_and_response_parts_contribute_to_scoring
    with_temp_home do |home|
      chats_dir = File.join(home, '.jules', 'chats')
      FileUtils.mkdir_p(chats_dir)

      messages = [
        { 'role' => 'user', 'parts' => [{ 'text' => 'check the deploy logs' }] },
        { 'role' => 'model', 'parts' => [
          { 'text' => 'looking' },
          { 'functionCall' => { 'name' => 'search', 'args' => { 'query' => 'production rollback cache' } } }
        ] },
        { 'role' => 'user', 'parts' => [
          { 'functionResponse' => { 'name' => 'search',
                                    'response' => { 'result' => 'production rollback cache found' } } }
        ] },
        { 'role' => 'model', 'parts' => [{ 'text' => 'summary' }] }
      ]
      File.write(File.join(chats_dir, 'c.json'), JSON.generate(messages))

      result = Jules::MemoryTool.new.call('query' => 'production rollback cache')

      assert_includes result, '[From c.json]'
    end
  end

  private

  def write_chat(path, user_text, model_text)
    messages = [
      { 'role' => 'user', 'parts' => [{ 'text' => user_text }] },
      { 'role' => 'model', 'parts' => [{ 'text' => model_text }] }
    ]
    File.write(path, JSON.pretty_generate(messages))
  end
end
