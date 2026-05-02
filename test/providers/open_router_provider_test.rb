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

  def test_mlx_provider_initializes_without_api_key
    provider = Jules::OpenAICompatibleProvider.new(preset: :mlx)

    assert_equal 'MLX', provider.provider_label
    assert_equal 'mlx-community/gemma-4-26b-a4b-it-4bit', provider.model
    refute_predicate provider, :lobotomized?
  end

  def test_mlx_provider_respects_model_override
    provider = Jules::OpenAICompatibleProvider.new(preset: :mlx, model: 'mlx-community/gemma-4-E4B-it-4bit')

    assert_equal 'mlx-community/gemma-4-E4B-it-4bit', provider.model
  end

  def test_mlx_provider_registered_under_mlx_name
    assert_includes Jules::Provider.all_names, 'mlx'
  end
end
