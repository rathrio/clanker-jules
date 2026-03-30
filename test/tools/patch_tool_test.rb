# frozen_string_literal: true

require_relative '../test_helper'

class PatchToolTest < Minitest::Test
  def test_returns_error_when_patch_is_empty
    result = PatchTool.new.call('patch' => '   ')

    assert_equal 'Error: patch cannot be empty.', result
  end

  def test_returns_error_when_path_does_not_exist
    result = PatchTool.new.call(
      'patch' => "--- a.txt\n+++ a.txt\n",
      'path' => '/tmp/definitely-missing-patch-path-123'
    )

    assert_match(/Error: path not found:/, result)
  end

  def test_returns_dry_run_success_message
    fake_status = status(success: true, exitstatus: 0)

    result = with_stubbed_singleton_method(
      Open3,
      :capture3,
      ->(*_args, **_kwargs) { ['checking file a.txt', '', fake_status] }
    ) do
      PatchTool.new.call(
        'patch' => "--- a.txt\n+++ a.txt\n@@ -1 +1 @@\n-old\n+new\n",
        'dry_run' => 'true'
      )
    end

    assert_equal "Dry-run successful:\nchecking file a.txt", result
  end

  def test_returns_patch_failed_message
    fake_status = status(success: false, exitstatus: 2)

    result = with_stubbed_singleton_method(
      Open3,
      :capture3,
      ->(*_args, **_kwargs) { ['', 'malformed patch', fake_status] }
    ) do
      PatchTool.new.call(
        'patch' => "--- a.txt\n+++ a.txt\nbad",
        'dry_run' => 'false'
      )
    end

    assert_equal "Patch failed:\nmalformed patch", result
  end
end
