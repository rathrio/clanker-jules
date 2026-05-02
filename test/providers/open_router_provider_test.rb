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

  def test_llamacpp_provider_initializes_without_api_key
    provider = Jules::OpenAICompatibleProvider.new(preset: :llamacpp)

    assert_equal 'llama.cpp', provider.provider_label
    assert_equal 'gemma-4-26b-a4b-it', provider.model
    refute_predicate provider, :lobotomized?
  end

  def test_llamacpp_provider_respects_model_override
    provider = Jules::OpenAICompatibleProvider.new(preset: :llamacpp, model: 'gemma-4-E4B-it')

    assert_equal 'gemma-4-E4B-it', provider.model
  end

  def test_llamacpp_provider_registered_under_llamacpp_name
    assert_includes Jules::Provider.all_names, 'llamacpp'
  end
end
