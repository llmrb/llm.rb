# frozen_string_literal: true

module LLM::OpenAI::Response
  module Completion
    ##
    # @return [String]
    #  Returns message content (usually a string)
    def content
      choices.find(&:assistant?).content
    end

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

    def model = body.model
    def prompt_tokens = usage["prompt_tokens"]
    def completion_tokens = usage["completion_tokens"]
    def total_tokens = usage["total_tokens"]
    def usage = body.usage || {}

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
