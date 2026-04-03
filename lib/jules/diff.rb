# frozen_string_literal: true

require 'shellwords'
require 'tempfile'

module Jules
  module Diff
    module_function

    def render_unified_diff(old_content:, new_content:, old_label:, new_label:)
      old_file = Tempfile.new('old')
      new_file = Tempfile.new('new')

      old_file.write(old_content.to_s)
      new_file.write(new_content.to_s)
      old_file.close
      new_file.close

      diff_command = [
        'diff -u',
        "-L #{old_label.shellescape}",
        "-L #{new_label.shellescape}",
        old_file.path.shellescape,
        new_file.path.shellescape
      ].join(' ')

      diff = `#{diff_command}`
      colorize(diff)
    ensure
      old_file&.unlink
      new_file&.unlink
    end

    def colorize(diff)
      diff.each_line.map do |line|
        if line.start_with?('+++') || line.start_with?('---')
          "\e[1m#{line}\e[0m"
        elsif line.start_with?('+')
          "\e[32m#{line}\e[0m"
        elsif line.start_with?('-')
          "\e[31m#{line}\e[0m"
        elsif line.start_with?('@@')
          "\e[36m#{line}\e[0m"
        else
          line
        end
      end.join
    end
  end
end
