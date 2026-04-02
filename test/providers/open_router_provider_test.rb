# frozen_string_literal: true

require_relative '../test_helper'
require 'json'
require 'timeout'
require 'net/http'
require 'jules'

class OpenAICompatibleProviderTest < Minitest::Test
  def test_generate_content_returns_error_result_on_network_timeout
    provider = Jules::OpenAICompatibleProvider.new(preset: :kiro)

    failing_http = Object.new
    failing_http.define_singleton_method(:use_ssl=) { |_value| nil }
    failing_http.define_singleton_method(:open_timeout=) { |_value| nil }
    failing_http.define_singleton_method(:read_timeout=) { |_value| nil }
    failing_http.define_singleton_method(:request) { |_request| raise Net::ReadTimeout, 'timed out' }

    with_stubbed_singleton_method(Net::HTTP, :new, ->(_host, _port) { failing_http }) do
      result = provider.generate_content([], [], system_prompt: 'system')

      assert_predicate result, :err?
      assert_equal 'provider_network_error', result.code
      assert_equal 'Kiro network error: Net::ReadTimeout - Net::ReadTimeout with "timed out"', result.message
    end
  end

  def test_generate_content_retries_then_returns_success_result
    provider = Jules::OpenAICompatibleProvider.new(preset: :kiro)

    call_count = 0
    flaky_http = Object.new
    flaky_http.define_singleton_method(:use_ssl=) { |_value| nil }
    flaky_http.define_singleton_method(:open_timeout=) { |_value| nil }
    flaky_http.define_singleton_method(:read_timeout=) { |_value| nil }
    flaky_http.define_singleton_method(:request) do |_request|
      call_count += 1
      raise Net::ReadTimeout, 'first timeout' if call_count == 1

      Struct.new(:body).new({ choices: [{ message: { content: 'ok' } }] }.to_json)
    end

    with_stubbed_singleton_method(Net::HTTP, :new, ->(_host, _port) { flaky_http }) do
      result = provider.generate_content([], [], system_prompt: 'system')

      assert_predicate result, :ok?
      assert_equal 'ok', result.value.dig('choices', 0, 'message', 'content')
      assert_equal 2, call_count
    end
  end
end
