# frozen_string_literal: true

require 'open3'

module TerminalMarkdownRenderer
  GLOW_ENV = {
    'CLICOLOR_FORCE' => '1',
    'COLORTERM' => 'truecolor',
    'TERM' => 'xterm-256color'
  }.freeze

  module_function

  def render(text)
    raise 'glow is required but was not found in PATH' unless glow_available?

    stdout, stderr, status = Open3.capture3(GLOW_ENV, 'glow', '-s', 'dracula', '-', stdin_data: text)

    raise "glow failed with exit status #{status.exitstatus}: #{stderr}" unless status.success?
    raise 'glow returned empty output' if stdout.strip.empty?

    stdout
  end

  def glow_available?
    return @glow_available unless @glow_available.nil?

    @glow_available = system('command -v glow > /dev/null 2>&1')
  end
end
