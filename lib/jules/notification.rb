# frozen_string_literal: true

require_relative 'script'

module Jules
  module Notification
    IDLE_TITLE = 'Jules needs a word.'

    NOTIFY_MESSAGES = [
      'The investigation has stalled. Jules is leaning on the desk, waiting for your next line.',
      'Jules finished talking. The cursor blinks like a metronome in an empty room.',
      "The cigarette's burning down. Jules needs direction before the ash hits the tray.",
      'The evidence is laid out. Jules is watching the door, waiting for you to walk through it.',
      'Jules has said the piece. The rest is your problem.',
      'The phone is off the hook. Jules is on the other end, saying nothing.',
      'Jules ran out of leads. Time for the client to talk.',
      'The typewriter stopped. Jules is staring at the blank page. Your line.',
      "The rain keeps falling but the case doesn't move without you.",
      "Jules cracked the knuckles and leaned back. Ball's in your court."
    ].freeze

    CRASH_TITLE = 'Jules is down.'

    CRASH_MESSAGES = [
      "Jules took a hit and didn't get back up. Check the terminal.",
      'Something went sideways. Jules is slumped over the desk.',
      'The line went dead. Jules needs a medic — or a restart.',
      'Jules collapsed mid-sentence. The case file is still open.',
      'A gunshot in the dark. Jules is down. Check the damage.',
      'The reel snapped. Jules is staring at static. You might want to look into it.'
    ].freeze

    module_function

    def notify_idle
      send_notification(IDLE_TITLE, NOTIFY_MESSAGES.sample, sound: 'Glass')
    end

    def notify_crash(error_message = nil)
      body = CRASH_MESSAGES.sample
      body = "#{body}\n#{error_message}" if error_message
      send_notification(CRASH_TITLE, body, sound: 'Sosumi')
    end

    def send_notification(title, message, sound: nil)
      script = "#{+'display notification "'}#{escape(message)}\" with title \"#{escape(title)}\""
      script << " sound name \"#{escape(sound)}\"" if sound
      system('osascript', '-e', script, out: File::NULL, err: File::NULL)
    rescue StandardError
      # Notifications are best-effort — never interrupt the session
    end

    def escape(str)
      str.to_s.gsub('\\', '\\\\\\\\').gsub('"', '\\\\"')
    end
  end
end
