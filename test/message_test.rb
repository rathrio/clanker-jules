# frozen_string_literal: true

require_relative 'test_helper'

class MessageTest < Minitest::Test
  def test_format_history_for_gemini_keeps_roles_and_parts
    history = [
      Jules::Message.new('user', [{ text: 'Find ruby files' }]),
      Jules::Message.new('model', [{ function_call: { name: 'glob', args: { 'pattern' => '**/*.rb' }, id: 'abc' } }]),
      Jules::Message.new('tool', [{ function_response: { name: 'glob', result: "a.rb\nb.rb", id: 'abc' } }]),
      Jules::Message.new('model', [{ text: 'Done.' }])
    ]

    result = Jules::Message.format_history(history, format: :gemini)

    assert_equal 'user', result[0][:role]
    assert_equal 'Find ruby files', result[0][:parts][0][:text]

    assert_equal 'model', result[1][:role]
    assert_equal 'glob', result[1][:parts][0][:functionCall][:name]
    assert_equal({ 'pattern' => '**/*.rb' }, result[1][:parts][0][:functionCall][:args])

    assert_equal 'user', result[2][:role]
    assert_equal 'glob', result[2][:parts][0][:functionResponse][:name]
    assert_equal "a.rb\nb.rb", result[2][:parts][0][:functionResponse][:response][:result]

    assert_equal 'model', result[3][:role]
    assert_equal 'Done.', result[3][:parts][0][:text]
  end

  def test_format_history_for_openai_splits_tool_messages_correctly
    history = [
      Jules::Message.new('user', [{ text: 'Run a tool' }]),
      Jules::Message.new('model', [{ function_call: { name: 'read', args: { 'path' => 'x.txt' }, id: 'call_1' } }]),
      Jules::Message.new('tool', [{ function_response: { name: 'read', result: 'content', id: 'call_1' } }]),
      Jules::Message.new('model', [{ text: 'Here you go' }])
    ]

    result = Jules::Message.format_history(history, format: :openai)

    assert_equal({ role: 'user', content: 'Run a tool' }, result[0])

    assert_equal 'assistant', result[1][:role]
    assert_equal 'read', result[1][:tool_calls][0][:function][:name]
    assert_equal({ 'path' => 'x.txt' }.to_json, result[1][:tool_calls][0][:function][:arguments])

    assert_equal({ role: 'tool', tool_call_id: 'call_1', content: 'content' }, result[2])
    assert_equal({ role: 'assistant', content: 'Here you go' }, result[3])
  end
end
