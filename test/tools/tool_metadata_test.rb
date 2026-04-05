# frozen_string_literal: true

require_relative '../test_helper'

class ToolMetadataTest < Minitest::Test
  TOOL_CLASSES = [
    Jules::BashTool,
    Jules::EditTool,
    Jules::FindCodeTool,
    Jules::GlobTool,
    Jules::LoadSkillTool,
    Jules::MemoryTool,
    Jules::NotificationTool,
    Jules::ReadTool,
    Jules::SearchTool,
    Jules::WriteTool
  ].freeze

  def test_every_tool_has_a_non_empty_description
    TOOL_CLASSES.each do |klass|
      description = klass.description

      assert_kind_of String, description, "#{klass} description must be a String"
      refute_empty description.strip, "#{klass} description must not be blank"
    end
  end

  def test_bash_tool_execution_summary_surfaces_command
    summary = Jules::BashTool.execution_summary('command' => 'ls -la')

    assert_equal 'ls -la', summary[:detail]
  end

  def test_edit_tool_execution_summary_surfaces_path
    summary = Jules::EditTool.execution_summary('path' => 'app/models/user.rb')

    assert_equal 'app/models/user.rb', summary[:detail]
  end

  def test_write_tool_execution_summary_surfaces_path
    summary = Jules::WriteTool.execution_summary('path' => 'README.md')

    assert_equal 'README.md', summary[:detail]
  end

  def test_load_skill_tool_execution_summary_surfaces_name
    summary = Jules::LoadSkillTool.execution_summary('name' => 'commit')

    assert_equal 'commit', summary[:detail]
  end

  def test_memory_tool_execution_summary_wraps_query_in_quotes
    summary = Jules::MemoryTool.execution_summary('query' => 'deploy failure')

    assert_equal '"deploy failure"', summary[:detail]
  end

  def test_notification_tool_execution_summary_surfaces_message
    summary = Jules::NotificationTool.execution_summary('message' => 'all done')

    assert_equal 'all done', summary[:detail]
  end

  def test_read_tool_execution_summary_without_range
    summary = Jules::ReadTool.execution_summary('path' => 'notes.txt')

    assert_equal 'notes.txt', summary[:detail]
  end

  def test_read_tool_execution_summary_with_full_range
    summary = Jules::ReadTool.execution_summary(
      'path' => 'notes.txt', 'start_line' => 10, 'end_line' => 20
    )

    assert_equal 'notes.txt (lines 10-20)', summary[:detail]
  end

  def test_read_tool_execution_summary_with_start_line_only
    summary = Jules::ReadTool.execution_summary('path' => 'notes.txt', 'start_line' => 10)

    assert_equal 'notes.txt (from line 10)', summary[:detail]
  end

  def test_glob_tool_execution_summary_uses_default_path_when_absent
    summary = Jules::GlobTool.execution_summary('pattern' => '**/*.rb')

    assert_equal '**/*.rb in .', summary[:detail]
  end

  def test_glob_tool_execution_summary_with_explicit_path
    summary = Jules::GlobTool.execution_summary('pattern' => '**/*.rb', 'path' => 'lib')

    assert_equal '**/*.rb in lib', summary[:detail]
  end

  def test_search_tool_execution_summary_uses_default_path_when_absent
    summary = Jules::SearchTool.execution_summary('query' => 'TODO')

    assert_equal '"TODO" in .', summary[:detail]
  end

  def test_search_tool_execution_summary_with_explicit_path
    summary = Jules::SearchTool.execution_summary('query' => 'TODO', 'path' => 'lib')

    assert_equal '"TODO" in lib', summary[:detail]
  end

  def test_find_code_tool_execution_summary_prefers_name_over_pattern
    summary = Jules::FindCodeTool.execution_summary(
      'name' => 'authenticate', 'pattern' => 'ignored'
    )

    assert_equal 'authenticate in .', summary[:detail]
  end

  def test_find_code_tool_execution_summary_falls_back_to_pattern
    summary = Jules::FindCodeTool.execution_summary('pattern' => 'foo()', 'path' => 'lib')

    assert_equal 'foo() in lib', summary[:detail]
  end
end
