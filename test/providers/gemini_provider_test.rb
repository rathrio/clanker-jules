# frozen_string_literal: true

require_relative '../test_helper'

class GeminiProviderTest < Minitest::Test
  def setup
    @original_api_key = ENV.fetch('GOOGLE_GENERATIVE_AI_API_KEY', nil)
    ENV['GOOGLE_GENERATIVE_AI_API_KEY'] = 'test-key'
    @provider = Jules::GeminiProvider.new(model: 'gemini-test')
  end

  def teardown
    if @original_api_key.nil?
      ENV.delete('GOOGLE_GENERATIVE_AI_API_KEY')
    else
      ENV['GOOGLE_GENERATIVE_AI_API_KEY'] = @original_api_key
    end
  end

  def test_parse_response_returns_error_for_thinking_only_response
    response = {
      'candidates' => [
        {
          'finishReason' => 'STOP',
          'content' => {
            'parts' => [
              { 'thought' => true, 'thoughtSignature' => 'abc123' }
            ]
          }
        }
      ]
    }

    result = @provider.parse_response(response)

    assert_predicate result, :err?
    assert_equal 'provider_response_error', result.code
    assert_includes result.message, 'Gemini returned only thinking parts with no text or tool calls'
    assert_includes result.message, 'finishReason: STOP'
  end

  def test_parse_response_prefers_tool_calls_when_present
    response = {
      'candidates' => [
        {
          'content' => {
            'parts' => [
              { 'thought' => true },
              { 'functionCall' => { 'name' => 'search', 'args' => { 'query' => 'foo' } } }
            ]
          }
        }
      ]
    }

    result = @provider.parse_response(response)

    assert_predicate result, :ok?
    assert_equal :tool_calls, result.value[:type]
    assert_equal [{ name: 'search', args: { 'query' => 'foo' }, id: nil }], result.value[:data]
  end
end
