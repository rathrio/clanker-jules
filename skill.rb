# frozen_string_literal: true

require 'yaml'

class Skill
  attr_reader :name, :description, :content

  def initialize(path)
    @path = path
    @name, @description, @content = parse_skill_file
  end

  def self.load_all
    skills_dir = File.expand_path('~/.agents/skills')
    skill_files = Dir.glob(File.join(skills_dir, '*/SKILL.md'))
    skill_files.map { |file| new(file) }.compact
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
