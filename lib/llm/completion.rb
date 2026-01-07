# frozen_string_literal: true

##
# Defines the interface all completion responses must implement
# @abstract
module LLM::Completion
  ##
  # @return [Array<LLM::Messsage>]
  #  Returns one or more messages
  def choices
    raise NotImplementedError, "#{self.class} does not implement '#{__method__}'"
  end
  alias_method :messages, :choices

  ##
  # @return [Integer]
  #  Returns the number of prompt tokens
  def prompt_tokens
    raise NotImplementedError, "#{self.class} does not implement '#{__method__}'"
  end

  ##
  # @return [Integer]
  #  Returns the number of completion tokens
  def completion_tokens
    raise NotImplementedError, "#{self.class} does not implement '#{__method__}'"
  end

  ##
  # @return [Integer]
  #  Returns the total number of tokens
  def total_tokens
    raise NotImplementedError, "#{self.class} does not implement '#{__method__}'"
  end

  ##
  # @return [LLM::Object, Hash]
  #  Returns usage information
  def usage
    raise NotImplementedError, "#{self.class} does not implement '#{__method__}'"
  end

  ##
  # @return [String]
  #  Returns the model name
  def model
    raise NotImplementedError, "#{self.class} does not implement '#{__method__}'"
  end
end
