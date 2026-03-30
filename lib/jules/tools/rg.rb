# frozen_string_literal: true

module Jules
  module Rg
    private

    def parse_globs(value)
      return [] if value.nil? || value.strip.empty?

      value.split(',').map(&:strip).reject(&:empty?)
    end

    def add_exclude_globs(command, globs)
      globs.each do |glob|
        command.push('--glob', "!#{glob.delete_prefix('!')}")
      end
      command
    end

    def relative_to_base(path, base_path)
      path.delete_prefix("#{base_path}/")
    end
  end
end
