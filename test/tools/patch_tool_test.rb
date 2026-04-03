# frozen_string_literal: true

require_relative '../test_helper'

class PatchToolTest < Minitest::Test
  def test_returns_error_when_patch_is_empty
    result = Jules::PatchTool.new.call('patch' => '   ')

    assert_equal 'Error: patch cannot be empty.', result
  end

  def test_returns_error_when_path_does_not_exist
    result = Jules::PatchTool.new.call(
      'patch' => "--- a.txt\n+++ a.txt\n",
      'path' => '/tmp/definitely-missing-patch-path-123'
    )

    assert_match(/Error: path not found:/, result)
  end

  def test_returns_clear_error_for_apply_patch_envelope_format
    result = Jules::PatchTool.new.call(
      'patch' => "*** Begin Patch\n*** Update File: a.txt\n@@\n-old\n+new\n*** End Patch\n",
      'dry_run' => 'true'
    )

    assert_equal(
      "Error: unsupported patch format. Please provide a standard unified diff starting with ---/+++ headers.\n" \
      'The *** Begin Patch / *** End Patch envelope is not supported by this tool.',
      result
    )
  end

  def test_applies_patch_and_returns_unified_diff_output
    Dir.mktmpdir do |dir|
      path = File.join(dir, 'note.txt')
      File.write(path, "old\n")

      patch_text = <<~PATCH
        --- note.txt
        +++ note.txt
        @@ -1 +1 @@
        -old
        +new
      PATCH

      result = Jules::PatchTool.new.call(
        'patch' => patch_text,
        'path' => dir
      )

      assert_includes result, '--- note.txt'
      assert_includes result, '+++ note.txt'
      assert_includes result, '-old'
      assert_includes result, '+new'
      assert_includes result, 'patching file'
      assert_equal "new\n", File.read(path)
    end
  end

  def test_dry_run_does_not_modify_files
    Dir.mktmpdir do |dir|
      path = File.join(dir, 'note.txt')
      File.write(path, "old\n")

      patch_text = <<~PATCH
        --- note.txt
        +++ note.txt
        @@ -1 +1 @@
        -old
        +new
      PATCH

      result = Jules::PatchTool.new.call(
        'patch' => patch_text,
        'path' => dir,
        'dry_run' => 'true'
      )

      assert_includes result, 'Dry-run successful'
      assert_equal "old\n", File.read(path)
    end
  end
end
