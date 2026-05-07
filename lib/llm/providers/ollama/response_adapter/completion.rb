# frozen_string_literal: true

module LLM::Ollama::ResponseAdapter
  module Completion
    ##
    # (see LLM::Contract::Completion#messages)
    def messages
      adapt_choices
    end
    alias_method :choices, :messages

    ##
    # (see LLM::Contract::Completion#input_tokens)
    def input_tokens
      body.prompt_eval_count || 0
    end

    ##
    # (see LLM::Contract::Completion#output_tokens)
    def output_tokens
      body.eval_count || 0
    end

    ##
    # (see LLM::Contract::Completion#reasoning_tokens)
    def reasoning_tokens
      0
    end

    ##
    # (see LLM::Contract::Completion#cache_read_tokens)
    def cache_read_tokens
      0
    end

    ##
    # (see LLM::Contract::Completion#cache_write_tokens)
    def cache_write_tokens
      0
    end

    ##
    # (see LLM::Contract::Completion#total_tokens)
    def total_tokens
      input_tokens + output_tokens
    end

    ##
    # (see LLM::Contract::Completion#usage)
    def usage
      super
    end

    ##
    # (see LLM::Contract::Completion#model)
    def model
      body.model
    end

    ##
    # (see LLM::Contract::Completion#content)
    def content
      super
    end

    ##
    # (see LLM::Contract::Completion#reasoning_content)
    def reasoning_content
      super
    end

    ##
    # (see LLM::Contract::Completion#content!)
    def content!
      super
    end

    private

    def adapt_choices
      message = body.message
      role, content, calls = message.role, message.content, message.tool_calls
      extra = {response: self, tool_calls: adapt_tool_calls(calls)}
      [LLM::Message.new(role, content, extra)]
    end

    def adapt_tool_calls(tools)
      return [] unless tools
      tools.filter_map do |tool|
        next unless tool["function"]
        tool["function"]
      end
    end

    include LLM::Contract::Completion
  end
end
