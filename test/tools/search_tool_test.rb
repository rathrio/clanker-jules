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

  def test_returns_matching_lines_as_relative_file_line_content
    Dir.mktmpdir do |dir|
      File.write(File.join(dir, 'a.rb'), "alpha\nneedle here\ngamma\n")
      File.write(File.join(dir, 'b.rb'), "just text\n")

      result = Jules::SearchTool.new.call('query' => 'needle', 'path' => dir)

      assert_equal 'a.rb:2:needle here', result
    end
  end

  def test_returns_no_matches_message_for_real_query_with_no_hits
    Dir.mktmpdir do |dir|
      File.write(File.join(dir, 'a.rb'), "hello\n")

      result = Jules::SearchTool.new.call('query' => 'zzz-nothing', 'path' => dir)

      assert_equal "No matches found for 'zzz-nothing'.", result
    end
  end

  def test_truncates_results_when_exceeding_max_results
    Dir.mktmpdir do |dir|
      File.write(File.join(dir, 'many.rb'), (["needle\n"] * 6).join)

      result = Jules::SearchTool.new.call(
        'query' => 'needle',
        'path' => dir,
        'max_results' => 2
      )

      lines = result.split("\n")

      assert_equal 3, lines.length
      assert_match(/truncated at 2 matches/, lines.last)
    end
  end

  def test_ignore_case_flag_matches_case_insensitively
    Dir.mktmpdir do |dir|
      File.write(File.join(dir, 'a.rb'), "HELLO world\n")

      result = Jules::SearchTool.new.call(
        'query' => 'hello',
        'path' => dir,
        'ignore_case' => 'true'
      )

      assert_match(/a\.rb:1:HELLO world/, result)
    end
  end

  def test_use_regex_matches_patterns
    Dir.mktmpdir do |dir|
      File.write(File.join(dir, 'a.rb'), "def create\ndef update\ndef show\n")

      result = Jules::SearchTool.new.call(
        'query' => 'def (create|update)',
        'path' => dir,
        'use_regex' => 'true'
      )

      assert_match(/a\.rb:1:def create/, result)
      assert_match(/a\.rb:2:def update/, result)
      refute_match(/def show/, result)
    end
  end

  def test_returns_full_file_path_when_base_path_is_a_file
    Dir.mktmpdir do |dir|
      file = File.join(dir, 'a.rb')
      File.write(file, "needle here\n")

      result = Jules::SearchTool.new.call('query' => 'needle', 'path' => file)

      assert_equal "#{file}:1:needle here", result
    end
  end
end
