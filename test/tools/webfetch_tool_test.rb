# frozen_string_literal: true

require 'net/http'
require_relative '../test_helper'

class WebfetchToolTest < Minitest::Test
  def test_returns_body_on_successful_http_response
    response = Object.new
    response.define_singleton_method(:body) { +'# Title' }
    response.define_singleton_method(:is_a?) do |klass|
      klass == Net::HTTPSuccess
    end

    result = with_stubbed_singleton_method(
      Net::HTTP,
      :get_response,
      ->(_uri) { response }
    ) do
      Jules::WebfetchTool.new.call('url' => 'https://example.com')
    end

    assert_equal '# Title', result
  end

  def test_returns_http_error_message_on_non_success_response
    response = Object.new
    response.define_singleton_method(:code) { '404' }
    response.define_singleton_method(:is_a?) { |_klass| false }

    result = with_stubbed_singleton_method(
      Net::HTTP,
      :get_response,
      ->(_uri) { response }
    ) do
      Jules::WebfetchTool.new.call('url' => 'https://example.com/missing')
    end

    assert_equal 'Error: Failed to fetch webpage. HTTP Status: 404', result
  end

  def test_returns_error_message_when_http_request_raises
    result = with_stubbed_singleton_method(
      Net::HTTP,
      :get_response,
      ->(_uri) { raise StandardError, 'timeout' }
    ) do
      Jules::WebfetchTool.new.call('url' => 'https://example.com')
    end

    assert_equal 'Error fetching webpage: timeout', result
  end
end
