# frozen_string_literal: true

module LLM::Ollama::Response
  module Completion
    ##
    # @return [String]
    #  Returns message content (usually a string)
    def content
      choices.find(&:assistant?).content
    end

    def model = body.model
    def prompt_tokens = body.prompt_eval_count || 0
    def completion_tokens = body.eval_count || 0
    def total_tokens = prompt_tokens + completion_tokens
    def message = body.message
    def choices = [format_choices]

    private

    def format_choices
      role, content, calls = message.to_h.values_at("role", "content", "tool_calls")
      extra = {response: self, tool_calls: format_tool_calls(calls)}
      LLM::Message.new(role, content, extra)
    end

    def format_tool_calls(tools)
      return [] unless tools
      tools.filter_map do |tool|
        next unless tool["function"]
        LLM::Object.new(tool["function"])
      end
    end
  end
end
