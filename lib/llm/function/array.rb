# frozen_string_literal: true

class LLM::Function
  ##
  # The {LLM::Function::Array} module extends the array
  # returned by {LLM::Session#functions} with methods
  # that can call all pending functions sequentially or
  # concurrently. The return values can be reported back
  # to the LLM on the next turn.
  module Array
    ##
    # Calls all functions in a collection sequentially.
    # @return [Array<LLM::Function::Return>]
    #  Returns values to be reported back to the LLM.
    def call
      map(&:call)
    end

    ##
    # Calls all functions in a collection concurrently.
    # This method returns an {LLM::Function::ThreadGroup}
    # that can be waited on to access the thread return
    # values.
    # @return [LLM::Function::ThreadGroup]
    def spawn
      ThreadGroup.new(map(&:spawn))
    end

    ##
    # Calls all functions in a collection concurrently
    # and waits for the thread return values.
    # @return [Array<LLM::Function::Return>]
    #  Returns values to be reported back to the LLM.
    def wait
      spawn.wait
    end
  end
end
