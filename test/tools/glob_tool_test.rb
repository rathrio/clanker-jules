# frozen_string_literal: true

require_relative '../test_helper'

class GlobToolTest < Minitest::Test
  def test_returns_error_when_pattern_is_empty
    result = GlobTool.new.call('pattern' => '   ')

    assert_equal 'Error: pattern cannot be empty.', result
  end

  def test_returns_error_when_path_does_not_exist
    result = GlobTool.new.call(
      'pattern' => '**/*.rb',
      'path' => '/tmp/definitely-missing-glob-path-123'
    )

    assert_match(/Error: path not found:/, result)
  end

  def test_returns_sorted_relative_matches
    Dir.mktmpdir do |dir|
      tool = GlobTool.new
      fake_stdout = "#{dir}/z.rb\n#{dir}/lib/a.rb\n"
      fake_status = status(success: true, exitstatus: 0)

      result = with_stubbed_singleton_method(
        Open3,
        :capture3,
        ->(*_command) { [fake_stdout, '', fake_status] }
      ) do
        tool.call('pattern' => '**/*.rb', 'path' => dir)
      end

      assert_equal "lib/a.rb\nz.rb", result
    end
  end

  def test_returns_no_files_message_when_rg_exitstatus_is_one
    tool = GlobTool.new
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
    tool = GlobTool.new
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
