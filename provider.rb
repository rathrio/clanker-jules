# frozen_string_literal: true

module Provider
  module ClassMethods
    def provider_name
      to_s.sub(/Provider$/, '').downcase
    end

    def register_provider(name = nil, **defaults)
      Provider.register(name || provider_name, self, **defaults)
    end
  end

  def self.included(klass)
    klass.extend(ClassMethods)
    klass.register_provider
  end

  def self.register(name, klass, **defaults)
    @known_providers ||= {}
    @known_providers[name] = { klass: klass, defaults: defaults }
  end

  def self.all_names
    (@known_providers || {}).keys.sort
  end

  def self.build(name, **overrides)
    provider = (@known_providers || {}).fetch(name)
    provider[:klass].new(**provider[:defaults], **overrides.compact)
  end

  def generate_content(_history, _tools, system_prompt: nil)
    raise NotImplementedError, "#{self.class} has not implemented method '#{__method__}'"
  end

  def parse_response(_response)
    raise NotImplementedError, "#{self.class} has not implemented method '#{__method__}'"
  end

  def tool_format
    raise NotImplementedError, "#{self.class} has not implemented method '#{__method__}'"
  end
end

Dir[File.join(__dir__, 'providers', '*_provider.rb')].each { |file| require file }
