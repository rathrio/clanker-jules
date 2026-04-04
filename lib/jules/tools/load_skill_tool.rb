# frozen_string_literal: true

require_relative '../skill'

module Jules
  class LoadSkillTool
    include Tool

    def self.description
      <<~DESC.chomp
        Load a skill (a reusable prompt/workflow) by name.

        Use this tool when:
        - The user asks you to run a skill or you need a specialized workflow
        - You've been told a skill exists for a particular task
      DESC
    end

    def self.execution_summary(args)
      { detail: args['name'] }
    end

    param name: 'name',
          type: String,
          description: 'The name of the skill to load.'

    def call(args)
      skill_name = args['name']
      skill = Jules::Skill.find(skill_name)

      if skill
        skill.content
      else
        "Skill not found: #{skill_name}"
      end
    end
  end
end
