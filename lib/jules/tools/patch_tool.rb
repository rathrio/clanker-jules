# frozen_string_literal: true

require 'open3'
require 'tempfile'

module Jules
  class PatchTool
    include Tool

    def self.description
      <<~DESC.chomp
        Apply a unified diff (patch) to one or more files. Supports dry-run to validate before applying.

        Use this tool when you:
        - Need to make multiple changes to a file in one operation
        - Have changes across several files to apply at once
        - Want to preview changes with dry_run=true before committing them

        Use edit for single, targeted replacements. Use write for creating new files.
      DESC
    end

    def self.render_execution(args)
      cwd = args['path'] || Dir.pwd
      label = truthy?(args['dry_run']) ? 'PATCH (DRY RUN)' : 'PATCH'
      "#{label}: #{cwd}"
    end

    param name: 'patch', type: String, description: 'Unified diff patch content to apply.'
    param name: 'path', type: String, description: 'Directory where patch should be applied (default: current directory).', optional: true
    param name: 'strip', type: Integer, description: 'Strip path components with -pN (default: 0).', optional: true
    param name: 'dry_run', type: String, description: 'Set to true to validate patch application without modifying files.', optional: true

    def call(params)
      patch_text = params.fetch('patch').to_s
      apply_path = File.expand_path(params['path'] || Dir.pwd)
      strip = (params['strip'] || 0).to_i
      dry_run = self.class.truthy?(params['dry_run'])

      return 'Error: patch cannot be empty.' if patch_text.strip.empty?
      return "Error: path not found: #{apply_path}" unless Dir.exist?(apply_path)

      Tempfile.create(['jules_patch', '.diff']) do |file|
        file.write(patch_text)
        file.flush

        command = build_command(file.path, strip, dry_run)
        stdout, stderr, status = Open3.capture3(*command, chdir: apply_path)
        format_result(status, stdout, stderr, dry_run)
      end
    end

    def self.truthy?(value)
      value.to_s.strip.downcase == 'true'
    end

    private

    def build_command(patch_file_path, strip, dry_run)
      command = [
        'patch',
        "-p#{strip}",
        '--forward',
        '--batch',
        '--reject-file=-'
      ]
      command << '--dry-run' if dry_run
      command + ['-i', patch_file_path]
    end

    def format_result(status, stdout, stderr, dry_run)
      output = [stdout, stderr].reject(&:empty?).join("\n").strip

      if status.success?
        return dry_run_success_message(output) if dry_run

        output.empty? ? 'Patch applied successfully.' : output
      elsif dry_run
        "Dry-run failed:\n#{output}"
      else
        "Patch failed:\n#{output}"
      end
    end

    def dry_run_success_message(output)
      return 'Dry-run successful. Patch can be applied cleanly.' if output.empty?

      "Dry-run successful:\n#{output}"
    end
  end
end
