# frozen_string_literal: true

require_relative '../test_helper'

class SemanticSearchToolTest < Minitest::Test
  def test_returns_error_when_pattern_is_empty
    result = SemanticSearchTool.new.call('pattern' => '   ')

    assert_equal 'Error: pattern cannot be empty.', result
  end

  def test_returns_error_when_path_does_not_exist
    result = SemanticSearchTool.new.call(
      'pattern' => 'puts($A)',
      'path' => '/tmp/definitely-missing-semantic-search-path-123'
    )

    assert_match(/Error: path not found:/, result)
  end

  def test_formats_successful_results_relative_to_base_path
    Dir.mktmpdir do |dir|
      tool = SemanticSearchTool.new
      payload_a = { 'file' => "#{dir}/lib/a.rb", 'range' => { 'start' => { 'line' => 3 } }, 'text' => 'puts :a' }
      payload_b = { 'file' => "#{dir}/lib/b.rb", 'range' => { 'start' => { 'line' => 7 } }, 'text' => 'puts :b' }
      fake_stdout = "#{JSON.generate(payload_a)}\n#{JSON.generate(payload_b)}\n"
      fake_status = status(success: true, exitstatus: 0)

      result = with_stubbed_singleton_method(
        Open3,
        :capture3,
        ->(*_command) { [fake_stdout, '', fake_status] }
      ) do
        tool.call('pattern' => 'puts($A)', 'path' => dir)
      end

      assert_equal "lib/a.rb:3:puts :a\nlib/b.rb:7:puts :b", result
    end
  end

  def test_returns_no_matches_message_when_ast_grep_exitstatus_is_one
    tool = SemanticSearchTool.new
    fake_status = status(success: false, exitstatus: 1)

    result = with_stubbed_singleton_method(
      Open3,
      :capture3,
      ->(*_command) { ['', '', fake_status] }
    ) do
      tool.call('pattern' => 'puts($A)')
    end

    assert_equal "No matches found for pattern 'puts($A)'.", result
  end

  def test_returns_ast_grep_error_message_when_ast_grep_fails
    tool = SemanticSearchTool.new
    fake_status = status(success: false, exitstatus: 2)

    result = with_stubbed_singleton_method(
      Open3,
      :capture3,
      ->(*_command) { ['', 'bad flag', fake_status] }
    ) do
      tool.call('pattern' => 'puts($A)')
    end

    assert_equal 'Error: ast-grep failed - bad flag', result
  end

  def test_returns_helpful_message_when_ast_grep_is_missing
    tool = SemanticSearchTool.new

    result = with_stubbed_singleton_method(
      Open3,
      :capture3,
      lambda { |_command, *_args|
        raise Errno::ENOENT
      }
    ) do
      tool.call('pattern' => 'puts($A)')
    end

    assert_equal 'Error: ast-grep is not installed or not in PATH.', result
  end

  def test_uses_globs_flag_for_excludes
    tool = SemanticSearchTool.new
    fake_status = status(success: true, exitstatus: 0)
    captured_command = nil

    with_stubbed_singleton_method(
      Open3,
      :capture3,
      lambda { |*command|
        captured_command = command
        ["{\"file\":\"foo.rb\",\"range\":{\"start\":{\"line\":1}},\"text\":\"x\"}\n", '', fake_status]
      }
    ) do
      tool.call('pattern' => 'puts($A)')
    end

    refute_nil captured_command
    refute_includes captured_command, '--glob'
    assert_includes captured_command, '--globs'
    assert_includes captured_command, '!**/.git/**'
  end
end
