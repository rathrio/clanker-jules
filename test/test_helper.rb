# frozen_string_literal: true

if ENV['COVERAGE']
  require 'simplecov'
  require 'simplecov_json_formatter'

  SimpleCov.start do
    enable_coverage :branch
    primary_coverage :line
    add_filter '/test/'
    track_files 'lib/**/*.rb'
    formatter SimpleCov::Formatter::MultiFormatter.new([
                                                         SimpleCov::Formatter::HTMLFormatter,
                                                         SimpleCov::Formatter::JSONFormatter
                                                       ])
  end
end

require 'minitest/autorun'
require 'tmpdir'
require 'fileutils'

$LOAD_PATH.unshift(File.expand_path('../lib', __dir__))

require 'jules'

module Minitest
  class Test
    def status(success:, exitstatus:)
      Struct.new(:exitstatus) do
        define_method(:success?) { success }
      end.new(exitstatus)
    end

    def with_temp_home
      Dir.mktmpdir do |home|
        original_home = Dir.home
        ENV['HOME'] = home
        yield home
      ensure
        ENV['HOME'] = original_home
        Jules::Skill.instance_variable_set(:@all, nil) if defined?(Jules::Skill)
      end
    end

    def with_stubbed_singleton_method(object, method_name, replacement_proc)
      singleton = class << object; self; end
      alias_name = "__original_#{method_name}_#{object_id}_#{rand(1000)}"

      singleton.alias_method(alias_name, method_name)
      singleton.define_method(method_name, &replacement_proc)
      yield
    ensure
      singleton.alias_method(method_name, alias_name)
      singleton.remove_method(alias_name)
    end
  end
end
