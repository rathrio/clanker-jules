# frozen_string_literal: true

require_relative '../test_helper'

class ReadToolTest < Minitest::Test
  def test_reads_full_file_when_no_line_range_is_given
    Dir.mktmpdir do |dir|
      path = File.join(dir, 'notes.txt')
      File.write(path, "line 1\nline 2\nline 3\n")

      result = Jules::ReadTool.new.call('path' => path)

      assert_equal "line 1\nline 2\nline 3\n", result
    end
  end

  def test_reads_only_requested_line_range
    Dir.mktmpdir do |dir|
      path = File.join(dir, 'notes.txt')
      File.write(path, "line 1\nline 2\nline 3\nline 4\n")

      result = Jules::ReadTool.new.call(
        'path' => path,
        'start_line' => 2,
        'end_line' => 3
      )

      assert_equal "line 2\nline 3\n", result
    end
  end

  def test_start_line_below_one_is_clamped_to_first_line
    Dir.mktmpdir do |dir|
      path = File.join(dir, 'notes.txt')
      File.write(path, "line 1\nline 2\n")

      result = Jules::ReadTool.new.call(
        'path' => path,
        'start_line' => -10,
        'end_line' => 1
      )

      assert_equal "line 1\n", result
    end
  end
end
