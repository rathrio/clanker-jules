# frozen_string_literal: true

require_relative '../test_helper'
require 'json'
require 'timeout'
require 'net/http'
require 'jules'

class OpenAICompatibleProviderTest < Minitest::Test
  def test_apfel_provider_initializes_without_api_key
    provider = Jules::OpenAICompatibleProvider.new(preset: :apfel)

    assert_equal 'Apfel', provider.provider_label
    assert_equal 'apple-foundationmodel', provider.model
    assert_predicate provider, :lobotomized?
  end

  def test_openrouter_provider_is_not_lobotomized
    ENV['OPENROUTER_API_KEY'] = 'test-key'
    provider = Jules::OpenAICompatibleProvider.new

    refute_predicate provider, :lobotomized?
  ensure
    ENV.delete('OPENROUTER_API_KEY')
  end
end
