# frozen_string_literal: true

require_relative 'test_helper'

class ToolTest < Minitest::Test
  def test_tool_call_runs_named_tool
    Dir.mktmpdir do |dir|
      path = File.join(dir, 'notes.txt')
      File.write(path, "one\ntwo\n")

      result = Jules::Tool.call('read', 'path' => path)

      assert_equal "one\ntwo\n", result
    end
  end

  def test_tool_call_wraps_errors_in_stable_error_message
    result = Jules::Tool.call('read', 'path' => '/tmp/definitely-missing-file-123.txt')

    assert_match(/Error executing tool 'read': Errno::ENOENT - /, result)
  end

  def test_tool_call_wraps_unknown_tool_errors
    result = Jules::Tool.call('not_a_real_tool', {})

    assert_match(/Error executing tool 'not_a_real_tool': KeyError - /, result)
  end
end
