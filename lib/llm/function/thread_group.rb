# frozen_string_literal: true

class LLM::Function
  class ThreadGroup
    ##
    # @param [Array<Thread>] threads
    #  An array of threads
    # @return [LLM::Function::ThreadGroup]
    def initialize(threads)
      @threads = threads
    end

    ##
    # Returns an array of function returns
    # @return [Array<LLM::Function::Return>]
    def wait
      @threads.map(&:value)
    end
  end
end
