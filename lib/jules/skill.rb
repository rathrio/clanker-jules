# frozen_string_literal: true

require 'yaml'

module Jules
  class Skill
    attr_reader :name, :description, :content

    @all = nil

    class << self
      def all
        @all ||= begin
          skills_dir = File.expand_path('~/.agents/skills')
          skill_files = Dir.glob(File.join(skills_dir, '*/SKILL.md'))

          skill_files.each_with_object({}) do |file, skills|
            skill = new(file)
            next unless skill.name

            skills[skill.name] = skill
          end
        end
      end

      def find(name)
        all[name]
      end
    end

    def initialize(path)
      @path = path
      @name, @description, @content = parse_skill_file
    end

    private

    def parse_skill_file
      raw_content = File.read(@path)
      frontmatter_match = raw_content.match(/---(.*?)---(.*)/m)

      if frontmatter_match
        frontmatter = YAML.safe_load(frontmatter_match[1])
        name = frontmatter['name']
        description = frontmatter['description']
        content = frontmatter_match[2].strip
        [name, description, content]
      else
        [nil, nil, nil]
      end
    end
  end
end
