# frozen_string_literal: true

module LLM::Gemini::Response
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
      body.modelVersion
    end

    ##
    # (see LLM::Completion#input_tokens)
    def input_tokens
      body.usageMetadata.promptTokenCount || 0
    end

    ##
    # (see LLM::Completion#output_tokens)
    def output_tokens
      body.usageMetadata.candidatesTokenCount || 0
    end

    ##
    # (see LLM::Completion#total_tokens)
    def total_tokens
      body.usageMetadata.totalTokenCount || 0
    end

    ##
    # (see LLM::Completion#usage)
    def usage
      super
    end

    private

    def format_choices
      candidates.map.with_index do |choice, index|
        choice = LLM::Object.from_hash(choice)
        content = choice.content || LLM::Object.new
        role = content.role || "model"
        parts = content.parts || [{"text" => choice.finishReason}]
        text  = parts.filter_map { _1["text"] }.join
        tools = parts.filter_map { _1["functionCall"] }
        extra = {index:, response: self, tool_calls: format_tool_calls(tools), original_tool_calls: tools}
        LLM::Message.new(role, text, extra)
      end
    end

    def format_tool_calls(tools)
      (tools || []).map do |tool|
        function = {name: tool.name, arguments: tool.args}
        LLM::Object.new(function)
      end
    end

    def candidates = body.candidates || []
  end
end
