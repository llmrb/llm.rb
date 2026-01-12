# frozen_string_literal: true

module LLM::Ollama::Response
  module Completion
    include LLM::Completion

    ##
    # (see LLM::Completion#usage)
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
      body.prompt_eval_count || 0
    end

    ##
    # (see LLM::Completion#output_tokens)
    def output_tokens
      body.completion_eval_count || 0
    end

    ##
    # (see LLM::Completion#total_tokens)
    def total_tokens
      input_tokens + output_tokens
    end

    private

    def format_choices
      role, content, calls = body.message.to_h.values_at("role", "content", "tool_calls")
      extra = {response: self, tool_calls: format_tool_calls(calls)}
      [LLM::Message.new(role, content, extra)]
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
