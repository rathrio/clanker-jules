# frozen_string_literal: true

require_relative '../test_helper'

class EditToolTest < Minitest::Test
  def test_replaces_unique_match_and_persists_change
    Dir.mktmpdir do |dir|
      path = File.join(dir, 'app.rb')
      File.write(path, "puts 'hello'\n")

      tool = EditTool.new
      tool.define_singleton_method(:display_diff) { |_file_path, _old_content, _new_content| nil }

      result = tool.call(
        'path' => path,
        'search' => "puts 'hello'",
        'replace' => "puts 'hi'"
      )

      assert_equal "Edited #{path}", result
      assert_equal "puts 'hi'\n", File.read(path)
    end
  end

  def test_returns_error_when_file_does_not_exist
    result = EditTool.new.call(
      'path' => '/tmp/does-not-exist.txt',
      'search' => 'a',
      'replace' => 'b'
    )

    assert_equal 'Error: File does not exist.', result
  end

  def test_returns_error_when_search_string_is_missing
    Dir.mktmpdir do |dir|
      path = File.join(dir, 'app.rb')
      File.write(path, "puts 'hello'\n")

      result = EditTool.new.call(
        'path' => path,
        'search' => "puts 'missing'",
        'replace' => "puts 'hi'"
      )

      assert_equal 'Error: Search string not found in file. Ensure exact whitespace matching.', result
    end
  end

  def test_returns_error_when_search_string_is_not_unique
    Dir.mktmpdir do |dir|
      path = File.join(dir, 'app.rb')
      File.write(path, "foo\nfoo\n")

      result = EditTool.new.call(
        'path' => path,
        'search' => 'foo',
        'replace' => 'bar'
      )

      assert_equal 'Error: Search string found 2 times. Provide more context to make it unique.', result
    end
  end
end
