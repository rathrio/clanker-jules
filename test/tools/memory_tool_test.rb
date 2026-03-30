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

  private

  def write_chat(path, user_text, model_text)
    messages = [
      { 'role' => 'user', 'parts' => [{ 'text' => user_text }] },
      { 'role' => 'model', 'parts' => [{ 'text' => model_text }] }
    ]
    File.write(path, JSON.pretty_generate(messages))
  end
end
