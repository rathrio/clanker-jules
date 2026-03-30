# frozen_string_literal: true

require_relative '../test_helper'

class WriteToolTest < Minitest::Test
  def test_writes_content_and_returns_original_path_argument
    Dir.mktmpdir do |dir|
      path = File.join(dir, 'output.txt')

      result = WriteTool.new.call(
        'path' => path,
        'content' => "hello\nworld\n"
      )

      assert_equal path, result
      assert_equal "hello\nworld\n", File.read(path)
    end
  end

  def test_overwrites_existing_file
    Dir.mktmpdir do |dir|
      path = File.join(dir, 'output.txt')
      File.write(path, 'old content')

      WriteTool.new.call(
        'path' => path,
        'content' => 'new content'
      )

      assert_equal 'new content', File.read(path)
    end
  end
end
