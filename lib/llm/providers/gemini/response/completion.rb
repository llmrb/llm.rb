# frozen_string_literal: true

module LLM::Gemini::Response
  module Completion
    ##
    # @return [String]
    #  Returns message content (usually a string)
    def content
      choices.find(&:assistant?).content
    end

    def model = body.modelVersion
    def prompt_tokens = body.usageMetadata.promptTokenCount
    def completion_tokens = body.usageMetadata.candidatesTokenCount
    def total_tokens = body.usageMetadata.totalTokenCount
    def choices = format_choices

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
