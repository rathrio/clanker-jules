# frozen_string_literal: true

require_relative 'test_helper'

class TerminalTest < Minitest::Test
  def setup
    Jules::Terminal::Markdown.remove_instance_variable(:@glow_available) if Jules::Terminal::Markdown.instance_variable_defined?(:@glow_available)
  end

  def teardown
    Jules::Terminal::Markdown.remove_instance_variable(:@glow_available) if Jules::Terminal::Markdown.instance_variable_defined?(:@glow_available)
  end

  def test_spinner_label_returns_a_known_take_with_ellipsis
    label = Jules::Terminal.spinner_label

    assert label.end_with?('...')

    sampled_take = label.delete_suffix('...')
    valid_takes = Jules::Terminal::CYNICAL_SPINNER_TAKES + ['clanking']

    assert_includes valid_takes, sampled_take
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

  def test_render_markdown_raises_when_output_is_only_whitespace
    success_status = status(success: true, exitstatus: 0)

    with_stubbed_singleton_method(Jules::Terminal::Markdown, :glow_available?, proc { true }) do
      with_stubbed_singleton_method(Open3, :capture3, proc { |_cmd, *_args, **_kwargs| ["\n", '', success_status] }) do
        error = assert_raises(RuntimeError) { Jules::Terminal::Markdown.render('hello') }
        assert_equal 'glow returned empty output', error.message
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
end
