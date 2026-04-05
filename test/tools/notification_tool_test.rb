# frozen_string_literal: true

require_relative '../test_helper'

class NotificationToolTest < Minitest::Test
  def test_raises_for_unknown_sound
    error = assert_raises(RuntimeError) do
      Jules::NotificationTool.new.call('message' => 'hi', 'sound' => 'NotARealSound')
    end

    assert_match(/Unknown sound 'NotARealSound'/, error.message)
    assert_match(/Available sounds:/, error.message)
  end

  def test_returns_notification_sent_for_valid_call
    # Notification.send_notification swallows any errors from osascript and
    # returns nil, so this test just verifies the tool's happy-path return value.
    result = Jules::NotificationTool.new.call('message' => 'hello', 'sound' => 'Glass')

    assert_equal 'Notification sent.', result
  end

  def test_defaults_to_glass_sound_when_sound_param_is_omitted
    result = Jules::NotificationTool.new.call('message' => 'no sound arg')

    assert_equal 'Notification sent.', result
  end
end
