# frozen_string_literal: true

class LLM::Session
  ##
  # @api private
  module Deserializer
    ##
    # @param [Hash] payload
    # @return [LLM::Message]
    def deserialize_message(payload)
      tool_calls = deserialize_tool_calls(payload["tools"])
      returns = deserialize_returns(payload["content"]) if returns.nil?
      original_tool_calls = payload["original_tool_calls"]
      extra = {tool_calls:, original_tool_calls:}.compact
      content = returns.nil? ? payload["content"] : returns
      LLM::Message.new(payload["role"], content, extra)
    end

    private

    def deserialize_tool_calls(items)
      items ||= []
      items.empty? ? nil : items
    end

    def deserialize_returns(items)
      returns = [*items].filter_map do |item|
        next unless Hash === item
        id, name, value = item.values_at("id", "name", "value")
        next if id.nil? || name.nil? || value.nil?
        LLM::Function::Return.new(id, name, value)
      end
      returns.empty? ? nil : returns
    end
  end
end
