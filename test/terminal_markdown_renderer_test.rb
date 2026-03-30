# frozen_string_literal: true

require_relative 'test_helper'
require_relative '../terminal_markdown_renderer'

class TerminalMarkdownRendererTest < Minitest::Test
  def setup
    TerminalMarkdownRenderer.remove_instance_variable(:@glow_available) if TerminalMarkdownRenderer.instance_variable_defined?(:@glow_available)
  end

  def teardown
    TerminalMarkdownRenderer.remove_instance_variable(:@glow_available) if TerminalMarkdownRenderer.instance_variable_defined?(:@glow_available)
  end

  def test_render_raises_when_glow_missing
    with_stubbed_singleton_method(TerminalMarkdownRenderer, :glow_available?, proc { false }) do
      error = assert_raises(RuntimeError) { TerminalMarkdownRenderer.render('hello') }
      assert_equal 'glow is required but was not found in PATH', error.message
    end
  end

  def test_render_raises_when_glow_command_fails
    failed_status = status(success: false, exitstatus: 7)

    with_stubbed_singleton_method(TerminalMarkdownRenderer, :glow_available?, proc { true }) do
      with_stubbed_singleton_method(Open3, :capture3, proc { |_cmd, *_args| ['', 'boom', failed_status] }) do
        error = assert_raises(RuntimeError) { TerminalMarkdownRenderer.render('hello') }
        assert_equal 'glow failed with exit status 7: boom', error.message
      end
    end
  end

  def test_render_raises_when_output_is_only_whitespace
    success_status = status(success: true, exitstatus: 0)

    with_stubbed_singleton_method(TerminalMarkdownRenderer, :glow_available?, proc { true }) do
      with_stubbed_singleton_method(Open3, :capture3, proc { |_cmd, *_args| ["\n", '', success_status] }) do
        error = assert_raises(RuntimeError) { TerminalMarkdownRenderer.render('hello') }
        assert_equal 'glow returned empty output', error.message
      end
    end
  end

  def test_render_passes_text_as_stdin_data
    captured = nil
    success_status = status(success: true, exitstatus: 0)

    with_stubbed_singleton_method(TerminalMarkdownRenderer, :glow_available?, proc { true }) do
      with_stubbed_singleton_method(Open3, :capture3, proc { |_cmd, *_args, **kwargs|
        captured = kwargs[:stdin_data]
        ['rendered', '', success_status]
      }) do
        TerminalMarkdownRenderer.render('hello')
      end
    end

    assert_equal 'hello', captured
  end
end
