# frozen_string_literal: true

require_relative 'test_helper'

class TerminalTest < Minitest::Test
  def setup
    Jules::Terminal.submit_hint_shown = false
    Jules::Terminal::Markdown.remove_instance_variable(:@glow_available) if Jules::Terminal::Markdown.instance_variable_defined?(:@glow_available)
  end

  def teardown
    Jules::Terminal.submit_hint_shown = false
    Jules::Terminal::Markdown.remove_instance_variable(:@glow_available) if Jules::Terminal::Markdown.instance_variable_defined?(:@glow_available)
  end

  def test_render_markdown_raises_when_glow_missing
    with_stubbed_singleton_method(Jules::Terminal::Markdown, :glow_available?, proc { false }) do
      error = assert_raises(RuntimeError) { Jules::Terminal::Markdown.render('hello') }
      assert_equal 'glow is required but was not found in PATH', error.message
    end
  end

  def test_render_markdown_raises_when_glow_command_fails
    failed_status = status(success: false, exitstatus: 7)

    with_stubbed_singleton_method(Jules::Terminal::Markdown, :glow_available?, proc { true }) do
      with_stubbed_singleton_method(Open3, :capture3, proc { |_cmd, *_args, **_kwargs| ['', 'boom', failed_status] }) do
        error = assert_raises(RuntimeError) { Jules::Terminal::Markdown.render('hello') }
        assert_equal 'glow failed with exit status 7: boom', error.message
      end
    end
  end

  def test_render_markdown_falls_back_to_raw_text_when_glow_output_is_only_whitespace
    success_status = status(success: true, exitstatus: 0)

    with_stubbed_singleton_method(Jules::Terminal::Markdown, :glow_available?, proc { true }) do
      with_stubbed_singleton_method(Open3, :capture3, proc { |_cmd, *_args, **_kwargs| ["\n", '', success_status] }) do
        assert_equal 'hello', Jules::Terminal::Markdown.render('hello')
      end
    end
  end

  def test_render_markdown_passes_text_as_stdin_data
    captured = nil
    success_status = status(success: true, exitstatus: 0)

    with_stubbed_singleton_method(Jules::Terminal::Markdown, :glow_available?, proc { true }) do
      with_stubbed_singleton_method(Open3, :capture3, proc { |_cmd, *_args, **kwargs|
        captured = kwargs[:stdin_data]
        ['rendered', '', success_status]
      }) do
        Jules::Terminal::Markdown.render('hello')
      end
    end

    assert_equal 'hello', captured
  end

  def test_render_markdown_passes_terminal_width_to_glow
    success_status = status(success: true, exitstatus: 0)
    capture3_args = nil

    with_stubbed_singleton_method(Jules::Terminal::Markdown, :glow_available?, proc { true }) do
      with_stubbed_singleton_method(Jules::Terminal::Markdown, :terminal_width, proc { 123 }) do
        with_stubbed_singleton_method(Open3, :capture3, proc { |_cmd, *args, **_kwargs|
          capture3_args = args
          ['rendered', '', success_status]
        }) do
          Jules::Terminal::Markdown.render('hello')
        end
      end
    end

    assert_equal ['glow', '-s', 'dracula', '-w', '123', '-'], capture3_args
  end

  def test_terminal_width_caps_at_max_render_width
    stub_console = Struct.new(:winsize).new([24, 200])

    with_stubbed_singleton_method(IO, :console, proc { stub_console }) do
      assert_equal 100, Jules::Terminal::Markdown.terminal_width
    end
  end

  def test_terminal_width_uses_actual_width_when_within_max
    stub_console = Struct.new(:winsize).new([24, 120])

    with_stubbed_singleton_method(IO, :console, proc { stub_console }) do
      assert_equal 100, Jules::Terminal::Markdown.terminal_width
    end
  end

  def test_terminal_width_falls_back_to_default_when_invalid
    stub_console = Struct.new(:winsize).new([24, 0])

    with_stubbed_singleton_method(IO, :console, proc { stub_console }) do
      assert_equal 80, Jules::Terminal::Markdown.terminal_width
    end
  end

  def test_print_submit_hint_mentions_send_and_exit_shortcuts
    output = capture_io { Jules::Terminal.print_submit_hint }.first

    assert_includes output, '(send: ctrl+s / alt+enter, exit: ctrl+d)'
  end

  def test_show_submit_hint_is_true_before_first_hint_is_shown
    Jules::Terminal.submit_hint_shown = false

    assert_predicate Jules::Terminal, :show_submit_hint?
  end

  def test_show_submit_hint_is_true_randomly_after_first_hint
    Jules::Terminal.submit_hint_shown = true

    with_stubbed_singleton_method(Kernel, :rand, proc { 0.1 }) do
      assert_predicate Jules::Terminal, :show_submit_hint?
    end
  end

  def test_show_submit_hint_can_be_false_after_first_hint
    Jules::Terminal.submit_hint_shown = true

    with_stubbed_singleton_method(Kernel, :rand, proc { 0.9 }) do
      refute_predicate Jules::Terminal, :show_submit_hint?
    end
  end
end
