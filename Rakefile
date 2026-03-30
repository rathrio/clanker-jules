# frozen_string_literal: true

require 'rake/testtask'

Rake::TestTask.new(:test) do |t|
  t.libs << 'test'
  t.pattern = 'test/**/*_test.rb'
  t.warning = false
  t.verbose = true
end

desc 'Run RuboCop lint checks'
task :lint do
  sh 'bundle exec rubocop'
end

desc 'Run tests and linting'
task ci: %i[test lint]

task default: :test
