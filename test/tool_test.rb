# frozen_string_literal: true

require_relative 'test_helper'

class ToolTest < Minitest::Test
  def test_tool_call_runs_named_tool
    Dir.mktmpdir do |dir|
      path = File.join(dir, 'notes.txt')
      File.write(path, "one\ntwo\n")

      result = Jules::Tool.call('read', 'path' => path)

      assert_predicate result, :ok?
      assert_equal "one\ntwo\n", result.value
    end
  end

  def test_tool_call_wraps_errors_in_stable_error_message
    result = Jules::Tool.call('read', 'path' => '/tmp/definitely-missing-file-123.txt')

    assert_predicate result, :err?
    assert_equal 'tool_execution_failed', result.code
    assert_match(/Error executing tool 'read': Errno::ENOENT - /, result.message)
  end

  def test_tool_call_wraps_unknown_tool_errors
    result = Jules::Tool.call('not_a_real_tool', {})

    assert_predicate result, :err?
    assert_equal 'tool_execution_failed', result.code
    assert_match(/Error executing tool 'not_a_real_tool': KeyError - Unknown tool 'not_a_real_tool'\./, result.message)
    assert_includes(result.message, 'Available tools:')
    assert_includes(result.message, 'read')
  end

  def test_tool_call_blocks_tools_outside_allowed_list_without_executing
    Dir.mktmpdir do |dir|
      path = File.join(dir, 'should_not_exist.txt')

      result = Jules::Tool.call(
        'write',
        { 'path' => path, 'content' => 'nope' },
        Jules::Tool::STAKEOUT_TOOLS
      )

      assert_predicate result, :err?
      assert_equal 'tool_blocked_stakeout', result.code
      assert_match(/Stakeout/i, result.message)
      refute_path_exists path, 'blocked write tool must not create the file'
    end
  end

  def test_tool_call_blocks_bash_under_stakeout_allowed_list
    Dir.mktmpdir do |dir|
      sentinel = File.join(dir, 'sentinel')

      result = Jules::Tool.call(
        'bash',
        { 'command' => "touch #{Shellwords.escape(sentinel)}" },
        Jules::Tool::STAKEOUT_TOOLS
      )

      assert_predicate result, :err?
      assert_equal 'tool_blocked_stakeout', result.code
      refute_path_exists sentinel, 'blocked bash tool must not run the command'
    end
  end

  def test_tool_call_executes_when_tool_is_in_allowed_list
    Dir.mktmpdir do |dir|
      path = File.join(dir, 'notes.txt')
      File.write(path, "hello\n")

      result = Jules::Tool.call('read', { 'path' => path }, Jules::Tool::STAKEOUT_TOOLS)

      assert_predicate result, :ok?
      assert_equal "hello\n", result.value
    end
  end

  def test_stakeout_tools_excludes_writers_and_shell
    refute_includes Jules::Tool::STAKEOUT_TOOLS, 'bash'
    refute_includes Jules::Tool::STAKEOUT_TOOLS, 'write'
    refute_includes Jules::Tool::STAKEOUT_TOOLS, 'edit'
  end

  def test_stakeout_tools_includes_read_only_inspectors
    %w[read glob search findcode webfetch memory].each do |name|
      assert_includes Jules::Tool::STAKEOUT_TOOLS, name
    end
  end
end
