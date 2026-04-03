# frozen_string_literal: true

require_relative '../notification'

module Jules
  class NotificationTool
    include Tool

    SOUNDS = %w[
      Basso
      Blow
      Bottle
      Frog
      Funk
      Glass
      Hero
      Morse
      Ping
      Pop
      Purr
      Sosumi
      Submarine
      Tink
    ].freeze

    def self.description
      <<~DESC.chomp
        Send a macOS system notification to the user with an optional sound.

        Use this tool when:
        - You need user input to continue and the user may not be watching the terminal
        - A long-running task has completed and you want to alert the user
        - Something unexpected happened that requires the user's attention

        Available sounds: #{SOUNDS.join(', ')}.
        Choose a sound that matches the tone of your notification — e.g. "Hero" for success, \
        "Basso" for errors, "Glass" for neutral prompts, "Ping" for gentle nudges.
      DESC
    end

    def self.render_execution(args)
      "NOTIFICATION: #{args['message']}"
    end

    param name: 'message', type: String, description: 'The notification message to display to the user'
    param name: 'sound', type: String, description: "The notification sound to play. Must be one of: #{SOUNDS.join(', ')}",
          optional: true

    def call(params)
      message = params.fetch('message')
      sound = params.fetch('sound', 'Glass')

      raise "Unknown sound '#{sound}'. Available sounds: #{SOUNDS.join(', ')}" unless SOUNDS.include?(sound)

      Jules::Notification.send_notification('Jules', message, sound: sound)
      'Notification sent.'
    end
  end
end
