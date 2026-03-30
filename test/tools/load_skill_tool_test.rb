# frozen_string_literal: true

require_relative '../test_helper'

class LoadSkillToolTest < Minitest::Test
  def test_loads_skill_content_when_skill_exists
    with_temp_home do |home|
      skill_dir = File.join(home, '.agents', 'skills', 'ruby')
      FileUtils.mkdir_p(skill_dir)

      File.write(File.join(skill_dir, 'SKILL.md'), <<~MARKDOWN)
        ---
        name: ruby_refactor
        description: Refactor Ruby methods safely
        ---
        Always preserve behavior.
      MARKDOWN

      result = LoadSkillTool.new.call('name' => 'ruby_refactor')

      assert_equal 'Always preserve behavior.', result
    end
  end

  def test_returns_not_found_message_when_skill_does_not_exist
    with_temp_home do
      result = LoadSkillTool.new.call('name' => 'missing_skill')

      assert_equal 'Skill not found: missing_skill', result
    end
  end
end
