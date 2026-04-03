# frozen_string_literal: true

require_relative '../notification'

module Jules
  class NotificationTool
    include Tool

    def self.description
      <<~DESC.chomp
        Send a system notification to the user.

        Use this tool when:
        - You need user input to continue and the user may not be watching the terminal
        - A long-running task has completed and you want to alert the user
        - Something unexpected happened that requires the user's attention

        The notification will appear as a macOS system notification with a sound.
      DESC
    end

    def self.render_execution(args)
      "NOTIFICATION: #{args['message']}"
    end

    param name: 'message', type: String, description: 'The notification message to display to the user'

    def call(params)
      message = params.fetch('message')
      Jules::Notification.send_notification('Jules', message, sound: 'Glass')
      'Notification sent.'
    end
  end
end
