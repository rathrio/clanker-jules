# frozen_string_literal: true

require_relative '../test_helper'

class BashToolTest < Minitest::Test
  def test_returns_combined_stdout_and_stderr
    command = "ruby -e 'STDOUT.print(\"out\\n\"); STDERR.print(\"err\\n\")'"

    result = Jules::BashTool.new.call('command' => command)

    assert_includes result, "out\n"
    assert_includes result, "err\n"
  end

  def test_raises_when_command_exits_non_zero
    error = assert_raises(RuntimeError) do
      Jules::BashTool.new.call('command' => "ruby -e 'exit 7'")
    end

    assert_includes error.message, 'Command failed with exit status 7'
    assert_includes error.message, "Working directory: #{Dir.pwd}"
  end

  def test_error_includes_command_output
    error = assert_raises(RuntimeError) do
      Jules::BashTool.new.call('command' => "ruby -e 'STDERR.puts(\"nope\"); exit 2'")
    end

    assert_includes error.message, 'Command output:'
    assert_includes error.message, 'nope'
  end
end
