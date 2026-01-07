# frozen_string_literal: true

module LLM::OpenAI::Response
  module Completion
    include LLM::Completion

    ##
    # (see LLM::Completion#choices)
    def choices
      body.choices.map.with_index do |choice, index|
        choice = LLM::Object.from_hash(choice)
        message = choice.message
        extra = {
          index:, response: self,
          logprobs: choice.logprobs,
          tool_calls: format_tool_calls(message.tool_calls),
          original_tool_calls: message.tool_calls
        }
        LLM::Message.new(message.role, message.content, extra)
      end
    end
    alias_method :messages, :choices

    ##
    # (see LLM::Completion#model)
    def model
      body.model
    end

    ##
    # (see LLM::Completion#prompt_tokens)
    def prompt_tokens
      usage["prompt_tokens"] || 0
    end

    ##
    # (see LLM::Completion#completion_tokens)
    def completion_tokens
      usage["completion_tokens"] || 0
    end

    ##
    # (see LLM::Completion#total_tokens)
    def total_tokens
      usage["total_tokens"] || 0
    end

    ##
    # (see LLM::Completion#usage)
    def usage
      body.usage || {}
    end

    private

    def format_tool_calls(tools)
      (tools || []).filter_map do |tool|
        next unless tool.function
        tool = {
          id: tool.id,
          name: tool.function.name,
          arguments: JSON.parse(tool.function.arguments)
        }
        LLM::Object.new(tool)
      end
    end
  end
end
