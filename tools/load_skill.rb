# frozen_string_literal: true

require_relative '../skill'

class LoadSkillTool
  include Tool

  def self.description
    'Load a skill by name. The skill content will be returned to you.'
  end

  param name: 'name',
        type: String,
        description: 'The name of the skill to load.'

  def call(args)
    skill_name = args['name']
    skill = Skill.load_all.find { |s| s.name == skill_name }

    if skill
      skill.content
    else
      "Skill not found: #{skill_name}"
    end
  end
end
