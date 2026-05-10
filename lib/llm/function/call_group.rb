# frozen_string_literal: true

class LLM::Function
  ##
  # The {LLM::Function::CallGroup} class wraps an array of
  # {LLM::Function} objects for sequential execution.
  #
  # It provides the same basic interface as the concurrent group
  # wrappers so callers can flow through `spawn(strategy).wait`
  # uniformly, even when the selected strategy is direct calls.
  class CallGroup
    ##
    # @param [Array<LLM::Function>] functions
    # @return [LLM::Function::CallGroup]
    def initialize(functions)
      @functions = functions
    end

    ##
    # @return [Boolean]
    def alive?
      false
    end

    ##
    # @return [nil]
    def interrupt!
      nil
    end
    alias_method :cancel!, :interrupt!

    ##
    # @return [Array<LLM::Function::Return>]
    def wait
      @functions.map(&:call)
    end
    alias_method :value, :wait
  end
end
