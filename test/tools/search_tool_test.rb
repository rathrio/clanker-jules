# frozen_string_literal: true

require_relative '../test_helper'

class SearchToolTest < Minitest::Test
  def test_returns_error_when_query_is_empty
    result = Jules::SearchTool.new.call('query' => '   ')

    assert_equal 'Error: query cannot be empty.', result
  end

  def test_returns_error_when_path_does_not_exist
    result = Jules::SearchTool.new.call(
      'query' => 'hello',
      'path' => '/tmp/definitely-missing-search-path-123'
    )

    assert_match(/Error: path not found:/, result)
  end

  def test_returns_error_for_invalid_regex_when_regex_mode_is_enabled
    result = Jules::SearchTool.new.call(
      'query' => '([a-z',
      'use_regex' => 'true'
    )

    assert_match(/Error: invalid regex - /, result)
  end

  def test_returns_no_matches_message_when_rg_exitstatus_is_one
    tool = Jules::SearchTool.new
    fake_status = status(success: false, exitstatus: 1)

    result = with_stubbed_singleton_method(
      Open3,
      :capture3,
      ->(*_command) { ['', '', fake_status] }
    ) do
      tool.call('query' => 'nothing')
    end

    assert_equal "No matches found for 'nothing'.", result
  end

  def test_returns_rg_error_message_when_rg_fails
    tool = Jules::SearchTool.new
    fake_status = status(success: false, exitstatus: 2)

    result = with_stubbed_singleton_method(
      Open3,
      :capture3,
      ->(*_command) { ['', 'bad flag', fake_status] }
    ) do
      tool.call('query' => 'anything')
    end

    assert_equal 'Error: rg failed - bad flag', result
  end
end
