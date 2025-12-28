# frozen_string_literal: true

module LLM::Anthropic::Response
  module Completion
    ##
    # @return [String]
    #  Returns message content (usually a string)  
    def content
      choices.find(&:assistant?).content
    end

    def choices = format_choices
    def role = body.role
    def model = body.model
    def prompt_tokens = body.usage["input_tokens"] || 0
    def completion_tokens = body.usage["output_tokens"] || 0
    def total_tokens = prompt_tokens + completion_tokens

    private

    def format_choices
      texts.map.with_index do |choice, index|
        extra = {
          index:, response: self,
          tool_calls: format_tool_calls(tools), original_tool_calls: tools
        }
        LLM::Message.new(role, choice["text"], extra)
      end
    end

    def format_tool_calls(tools)
      (tools || []).filter_map do |tool|
        tool = {
          id: tool.id,
          name: tool.name,
          arguments: tool.input
        }
        LLM::Object.new(tool)
      end
    end

    def parts = body.content
    def texts = @texts ||= LLM::Object.from_hash(parts.select { _1["type"] == "text" })
    def tools = @tools ||= LLM::Object.from_hash(parts.select { _1["type"] == "tool_use" })
  end
end
