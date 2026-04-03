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
        - Want to preview changes with dry_run=true to validate before applying

        Use edit for single, targeted replacements. Use write for creating new files or full rewrites.
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
      return unsupported_patch_format_error if apply_patch_envelope?(patch_text)
      return "Error: path not found: #{apply_path}" unless Dir.exist?(apply_path)

      touched_files = parse_touched_files(patch_text, strip)
      original_content = capture_original_content(apply_path, touched_files)

      Tempfile.create(['jules_patch', '.diff']) do |file|
        file.write(patch_text)
        file.flush

        command = build_command(file.path, strip, dry_run)
        stdout, stderr, status = Open3.capture3(*command, chdir: apply_path)
        diff_output = if status.success? && !dry_run
                        render_diff_output(apply_path, touched_files, original_content)
                      else
                        ''
                      end

        format_result(status, stdout, stderr, dry_run, diff_output)
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

    def format_result(status, stdout, stderr, dry_run, diff_output)
      output = [stdout, stderr].reject(&:empty?).join("\n").strip

      if status.success?
        return dry_run_success_message(output) if dry_run

        success_message = output.empty? ? 'Patch applied successfully.' : output
        return success_message if diff_output.to_s.strip.empty?

        "#{diff_output}\n#{success_message}"
      elsif dry_run
        "Dry-run failed:\n#{output}"
      else
        "Patch failed:\n#{output}"
      end
    end

    def parse_touched_files(patch_text, strip)
      touched_files = []
      current_old = nil

      patch_text.each_line do |line|
        current_old = normalize_patch_path(line, strip) if line.start_with?('--- ')

        next unless line.start_with?('+++ ')

        current_new = normalize_patch_path(line, strip)
        touched_files << { old: current_old, new: current_new }
        current_old = nil
      end

      touched_files
    end

    def normalize_patch_path(line, strip)
      raw_path = line.split(' ', 2).last.to_s.split(/[\t\s]/, 2).first.to_s
      return nil if raw_path.empty? || raw_path == File::NULL

      parts = raw_path.sub(%r{\A\./}, '').split('/')
      stripped = parts.drop(strip)
      return nil if stripped.empty?

      stripped.join('/')
    end

    def capture_original_content(apply_path, touched_files)
      paths = touched_files.flat_map { |entry| [entry[:old], entry[:new]] }.compact.uniq

      paths.to_h do |relative_path|
        full_path = File.join(apply_path, relative_path)
        content = File.exist?(full_path) ? File.read(full_path) : nil
        [relative_path, content]
      end
    end

    def render_diff_output(apply_path, touched_files, original_content)
      touched_files.filter_map do |entry|
        old_path = entry[:old]
        new_path = entry[:new]
        old_label = old_path || File::NULL
        new_label = new_path || File::NULL
        old_content = old_path ? original_content.fetch(old_path, nil) : nil

        new_content = if new_path
                        updated_path = File.join(apply_path, new_path)
                        File.exist?(updated_path) ? File.read(updated_path) : nil
                      end

        diff = Jules::Diff.render_unified_diff(
          old_content: old_content,
          new_content: new_content,
          old_label: old_label,
          new_label: new_label
        )

        diff unless diff.to_s.strip.empty?
      end.join("\n")
    end

    def apply_patch_envelope?(patch_text)
      lines = patch_text.lines
      return false if lines.empty?

      first_line = lines.first.strip
      last_line = lines.rfind { |line| !line.strip.empty? }&.strip

      first_line == '*** Begin Patch' || last_line == '*** End Patch'
    end

    def unsupported_patch_format_error
      <<~ERROR.chomp
        Error: unsupported patch format. Please provide a standard unified diff starting with ---/+++ headers.
        The *** Begin Patch / *** End Patch envelope is not supported by this tool.
      ERROR
    end

    def dry_run_success_message(output)
      return 'Dry-run successful. Patch can be applied cleanly.' if output.empty?

      "Dry-run successful:\n#{output}"
    end
  end
end
