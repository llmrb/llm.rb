# frozen_string_literal: true

module LLM::Anthropic::Response
  module Completion
    include LLM::Completion
    ##
    # (see LLM::Completion#choices)
    def choices
      format_choices
    end
    alias_method :messages, :choices

    ##
    # (see LLM::Completion#model)
    def model
      body.model
    end

    ##
    # (see LLM::Completion#input_tokens)
    def input_tokens
      body.usage["input_tokens"] || 0
    end

    ##
    # (see LLM::Completion#output_tokens)
    def output_tokens
      body.usage["output_tokens"] || 0
    end

    ##
    # (see LLM::Completion#total_tokens)
    def total_tokens
      input_tokens + output_tokens
    end

    ##
    # (see LLM::Completion#usage)
    def usage
      super
    end

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
