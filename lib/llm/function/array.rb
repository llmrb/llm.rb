# frozen_string_literal: true

class LLM::Function
  ##
  # The {LLM::Function::Array} module extends the array
  # returned by {LLM::Session#functions} with methods
  # that can call all pending functions sequentially or
  # concurrently. Both methods return values that can be
  # reported back to the LLM on the next turn.
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
    # This method waits for the threads to finish and
    # returns their values.
    # @return [Array<LLM::Function::Return>]
    #  Returns values to be reported back to the LLM.
    def call!
      spawn.map(&:value)
    end

    ##
    # Calls all functions in a collection concurrently.
    # This method returns an array of Thread objects that
    # can be waited on later.
    # @return [Array<Thread>]
    def spawn!
      map(&:call!)
    end
  end
end
