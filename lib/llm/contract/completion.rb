# frozen_string_literal: true

module LLM::Contract
  ##
  # Defines the interface all completion responses must implement
  # @abstract
  module Completion
    extend LLM::Contract

    ##
    # @return [Array<LLM::Messsage>]
    #  Returns one or more messages
    def messages
      raise NotImplementedError, "#{self.class} does not implement '#{__method__}'"
    end
    alias_method :choices, :messages

    ##
    # @return [Integer]
    #  Returns the number of input tokens
    def input_tokens
      raise NotImplementedError, "#{self.class} does not implement '#{__method__}'"
    end

    ##
    # @return [Integer]
    #  Returns the number of output tokens
    def output_tokens
      raise NotImplementedError, "#{self.class} does not implement '#{__method__}'"
    end

    ##
    # @return [Integer]
    # Returns the number of reasoning tokens
    def reasoning_tokens
      raise NotImplementedError, "#{self.class} does not implement '#{__method__}'"
    end

    ##
    # @return [Integer]
    #  Returns the number of input audio tokens, or 0 when the
    #  provider does not report input audio usage
    def input_audio_tokens
      0
    end

    ##
    # @return [Integer]
    #  Returns the number of output audio tokens, or 0 when the
    #  provider does not report output audio usage
    def output_audio_tokens
      0
    end

    ##
    # @return [Integer]
    #  Returns the number of cached input tokens, or 0 when the
    #  provider does not report cache usage
    def cache_read_tokens
      0
    end

    ##
    # @return [Integer]
    #  Returns the number of cache creation input tokens, or 0 when the
    #  provider does not report cache creation usage
    def cache_write_tokens
      0
    end

    ##
    # @return [Integer]
    #  Returns the total number of tokens
    def total_tokens
      raise NotImplementedError, "#{self.class} does not implement '#{__method__}'"
    end

    ##
    # @return [String]
    #  Returns the LLM response
    def content
      messages.find(&:assistant?).content
    end

    ##
    # @return [String, nil]
    #  Returns the reasoning content when the provider exposes it
    def reasoning_content
      messages.find(&:assistant?)&.reasoning_content
    end

    ##
    # @return [Hash]
    #  Returns the LLM response after parsing it as JSON
    def content!
      LLM.json.load(content)
    end

    ##
    # @return [LLM::Usage]
    #  Returns usage information
    def usage
      LLM::Usage.new(
        input_tokens:,
        output_tokens:,
        reasoning_tokens:,
        input_audio_tokens:,
        output_audio_tokens:,
        cache_read_tokens:,
        cache_write_tokens:,
        total_tokens:
      )
    end

    ##
    # @return [String]
    #  Returns the model name
    def model
      raise NotImplementedError, "#{self.class} does not implement '#{__method__}'"
    end
  end
end
