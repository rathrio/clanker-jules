# frozen_string_literal: true

require_relative '../test_helper'

class GlobToolTest < Minitest::Test
  def test_returns_error_when_pattern_is_empty
    result = Jules::GlobTool.new.call('pattern' => '   ')

    assert_equal 'Error: pattern cannot be empty.', result
  end

  def test_returns_error_when_path_does_not_exist
    result = Jules::GlobTool.new.call(
      'pattern' => '**/*.rb',
      'path' => '/tmp/definitely-missing-glob-path-123'
    )

    assert_match(/Error: path not found:/, result)
  end

  def test_returns_no_files_message_when_rg_exitstatus_is_one
    tool = Jules::GlobTool.new
    fake_status = status(success: false, exitstatus: 1)

    result = with_stubbed_singleton_method(
      Open3,
      :capture3,
      ->(*_command) { ['', '', fake_status] }
    ) do
      tool.call('pattern' => '**/*.rb')
    end

    assert_equal "No files matched pattern '**/*.rb'.", result
  end

  def test_returns_rg_error_message_when_rg_fails
    tool = Jules::GlobTool.new
    fake_status = status(success: false, exitstatus: 2)

    result = with_stubbed_singleton_method(
      Open3,
      :capture3,
      ->(*_command) { ['', 'rg crashed', fake_status] }
    ) do
      tool.call('pattern' => '**/*.rb')
    end

    assert_equal 'Error: rg failed - rg crashed', result
  end
end
