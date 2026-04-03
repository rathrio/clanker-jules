# frozen_string_literal: true

require_relative 'test_helper'

class TerminalTest < Minitest::Test
  def setup
    Jules::Terminal.submit_hint_shown = false
  end

  def teardown
    Jules::Terminal.submit_hint_shown = false
  end

  def test_print_submit_hint_mentions_send_and_exit_shortcuts
    output = capture_io { Jules::Terminal.print_submit_hint }.first

    assert_includes output, '(send: ctrl+s / alt+enter, exit: ctrl+d)'
  end

  def test_show_submit_hint_is_true_before_first_hint_is_shown
    Jules::Terminal.submit_hint_shown = false

    assert_predicate Jules::Terminal, :show_submit_hint?
  end

  def test_print_model_usage_shows_usage_only_without_models
    output = capture_io { Jules::Terminal.print_model_usage }.first

    assert_includes output, '(usage: /model <model-name>)'
    refute_includes output, '(available models:)'
  end

  def test_print_model_usage_shows_available_models_when_provided
    output = capture_io { Jules::Terminal.print_model_usage(models: %w[gpt-4o gemini-flash-latest]) }.first

    assert_includes output, '(usage: /model <model-name>)'
    assert_includes output, '(available models:)'
    assert_includes output, '- gpt-4o'
    assert_includes output, '- gemini-flash-latest'
  end

  def test_print_tool_preview_shows_full_edit_output_without_truncation
    result = (1..8).map { |i| "line #{i}" }.join("\n")

    output = capture_io { Jules::Terminal.print_tool_preview('edit', result) }.first

    assert_includes output, 'line 1'
    assert_includes output, 'line 8'
    refute_includes output, 'more lines'
  end

  def test_print_tool_preview_truncates_non_edit_tool_output
    result = (1..8).map { |i| "line #{i}" }.join("\n")

    output = capture_io { Jules::Terminal.print_tool_preview('search', result) }.first

    assert_includes output, 'line 1'
    assert_includes output, 'line 5'
    refute_includes output, 'line 6'
    assert_includes output, '… 3 more lines'
  end

  def test_print_tool_preview_treats_carriage_returns_as_line_breaks
    result = "line 1\rline 2\rline 3"

    output = capture_io { Jules::Terminal.print_tool_preview('bash', result) }.first
    line_count = output.lines.count { |line| line.include?('line ') }

    assert_equal 3, line_count
  end

  def test_parse_slash_command_recognizes_known_skill_name
    command = Jules::Terminal.parse_slash_command('/obsidian', skill_names: ['obsidian'])

    assert_equal [:skill, 'obsidian'], command
  end

  def test_parse_slash_command_ignores_unknown_skill_name
    command = Jules::Terminal.parse_slash_command('/unknown', skill_names: ['obsidian'])

    assert_nil command
  end

  def test_spinner_scene_direction_uses_parenthetical_format
    output = Jules::Terminal.spinner_scene_direction('Jules is clanking.', '⠋')

    assert_includes output, '(Jules is clanking. '
    assert_includes output, '⠋'
    assert_includes output, ')'
  end
end
