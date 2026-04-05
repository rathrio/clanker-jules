# frozen_string_literal: true

require_relative '../test_helper'

class GlobToolTest < Minitest::Test
  def test_returns_error_when_pattern_is_empty
    result = Jules::GlobTool.new.call('pattern' => '   ')

    assert_equal 'Error: pattern cannot be empty.', result
  end

  def test_returns_error_when_path_does_not_exist
    result = Jules::GlobTool.new.call(
      'pattern' => '**/*.rb',
      'path' => '/tmp/definitely-missing-glob-path-123'
    )

    assert_match(/Error: path not found:/, result)
  end

  def test_returns_no_files_message_when_rg_exitstatus_is_one
    tool = Jules::GlobTool.new
    fake_status = status(success: false, exitstatus: 1)

    result = with_stubbed_singleton_method(
      Open3,
      :capture3,
      ->(*_command) { ['', '', fake_status] }
    ) do
      tool.call('pattern' => '**/*.rb')
    end

    assert_equal "No files matched pattern '**/*.rb'.", result
  end

  def test_returns_rg_error_message_when_rg_fails
    tool = Jules::GlobTool.new
    fake_status = status(success: false, exitstatus: 2)

    result = with_stubbed_singleton_method(
      Open3,
      :capture3,
      ->(*_command) { ['', 'rg crashed', fake_status] }
    ) do
      tool.call('pattern' => '**/*.rb')
    end

    assert_equal 'Error: rg failed - rg crashed', result
  end

  def test_returns_matching_files_as_paths_relative_to_base
    Dir.mktmpdir do |dir|
      FileUtils.mkdir_p(File.join(dir, 'src'))
      File.write(File.join(dir, 'a.rb'), '')
      File.write(File.join(dir, 'src', 'b.rb'), '')
      File.write(File.join(dir, 'src', 'c.txt'), '')

      result = Jules::GlobTool.new.call('pattern' => '**/*.rb', 'path' => dir)

      assert_equal "a.rb\nsrc/b.rb", result
    end
  end

  def test_returns_no_files_message_when_no_real_matches_exist
    Dir.mktmpdir do |dir|
      File.write(File.join(dir, 'keep.txt'), '')

      result = Jules::GlobTool.new.call('pattern' => '**/*.rb', 'path' => dir)

      assert_equal "No files matched pattern '**/*.rb'.", result
    end
  end

  def test_truncates_matches_when_exceeding_max_results
    Dir.mktmpdir do |dir|
      5.times { |i| File.write(File.join(dir, "file_#{i}.rb"), '') }

      result = Jules::GlobTool.new.call(
        'pattern' => '**/*.rb',
        'path' => dir,
        'max_results' => 2
      )

      lines = result.split("\n")

      assert_equal 3, lines.length
      assert_equal '...truncated at 2 files.', lines.last
    end
  end

  def test_excludes_paths_matching_exclude_glob
    Dir.mktmpdir do |dir|
      File.write(File.join(dir, 'keep.rb'), '')
      File.write(File.join(dir, 'skip.rb'), '')

      result = Jules::GlobTool.new.call(
        'pattern' => '**/*.rb',
        'path' => dir,
        'exclude_glob' => 'skip.rb'
      )

      assert_equal 'keep.rb', result
    end
  end

  def test_include_dotfiles_flag_passes_hidden_option_to_rg_without_error
    Dir.mktmpdir do |dir|
      File.write(File.join(dir, 'visible.rb'), '')

      result = Jules::GlobTool.new.call(
        'pattern' => '**/*.rb',
        'path' => dir,
        'include_dotfiles' => 'true'
      )

      assert_equal 'visible.rb', result
    end
  end
end
