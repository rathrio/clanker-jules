# frozen_string_literal: true

require_relative '../test_helper'

class FindCodeToolTest < Minitest::Test
  def test_returns_error_when_neither_name_nor_pattern_provided
    result = Jules::FindCodeTool.new.call({})

    assert_equal 'Error: provide either name or pattern.', result
  end

  def test_returns_error_when_pattern_is_blank
    result = Jules::FindCodeTool.new.call('pattern' => '   ')

    assert_equal 'Error: provide either name or pattern.', result
  end

  def test_returns_error_when_name_used_without_lang
    result = Jules::FindCodeTool.new.call('name' => 'foo')

    assert_equal 'Error: lang is required when using name.', result
  end

  def test_returns_error_when_path_does_not_exist
    result = Jules::FindCodeTool.new.call(
      'pattern' => 'puts($A)',
      'path' => '/tmp/definitely-missing-find-code-path-123'
    )

    assert_match(/Error: path not found:/, result)
  end

  def test_formats_successful_results_relative_to_base_path
    Dir.mktmpdir do |dir|
      tool = Jules::FindCodeTool.new
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

      assert_includes result, 'lib/a.rb:3'
      assert_includes result, '  puts :a'
      assert_includes result, 'lib/b.rb:7'
      assert_includes result, '  puts :b'
    end
  end

  def test_formats_meta_variables
    Dir.mktmpdir do |dir|
      tool = Jules::FindCodeTool.new
      payload = {
        'file' => "#{dir}/lib/a.rb",
        'range' => { 'start' => { 'line' => 1 } },
        'text' => 'puts :hello',
        'metaVariables' => {
          'single' => { 'A' => { 'text' => ':hello' } },
          'multi' => {},
          'transformed' => {}
        }
      }
      fake_stdout = "#{JSON.generate(payload)}\n"
      fake_status = status(success: true, exitstatus: 0)

      result = with_stubbed_singleton_method(
        Open3,
        :capture3,
        ->(*_command) { [fake_stdout, '', fake_status] }
      ) do
        tool.call('pattern' => 'puts($A)', 'path' => dir)
      end

      assert_includes result, 'lib/a.rb:1'
      assert_includes result, 'vars: $A=:hello'
      assert_includes result, '  puts :hello'
    end
  end

  def test_truncates_long_matches
    Dir.mktmpdir do |dir|
      tool = Jules::FindCodeTool.new
      long_text = (1..15).map { |i| "  line_#{i}" }.join("\n")
      payload = {
        'file' => "#{dir}/lib/a.rb",
        'range' => { 'start' => { 'line' => 1 } },
        'text' => long_text
      }
      fake_stdout = "#{JSON.generate(payload)}\n"
      fake_status = status(success: true, exitstatus: 0)

      result = with_stubbed_singleton_method(
        Open3,
        :capture3,
        ->(*_command) { [fake_stdout, '', fake_status] }
      ) do
        tool.call('pattern' => '$X', 'path' => dir)
      end

      assert_includes result, '... (5 more lines)'
    end
  end

  def test_returns_no_matches_message_when_exitstatus_is_one
    tool = Jules::FindCodeTool.new
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

  def test_returns_error_message_when_ast_grep_fails
    tool = Jules::FindCodeTool.new
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
    tool = Jules::FindCodeTool.new

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

  def test_name_search_formats_results
    Dir.mktmpdir do |dir|
      tool = Jules::FindCodeTool.new
      payload = {
        'file' => "#{dir}/lib/a.rb",
        'range' => { 'start' => { 'line' => 1 } },
        'text' => "def perform\n  do_work\nend",
        'metaVariables' => { 'single' => {}, 'multi' => { 'secondary' => [{ 'text' => 'perform' }] }, 'transformed' => {} },
        'ruleId' => 'find', 'severity' => 'hint', 'note' => nil, 'message' => '', 'labels' => []
      }
      fake_stdout = "#{JSON.generate(payload)}\n"
      fake_status = status(success: true, exitstatus: 0)

      result = with_stubbed_singleton_method(
        Open3,
        :capture3,
        ->(*_command) { [fake_stdout, '', fake_status] }
      ) do
        tool.call('name' => 'perform', 'lang' => 'ruby', 'path' => dir)
      end

      assert_includes result, 'lib/a.rb:1'
      assert_includes result, '  def perform'
    end
  end
end
