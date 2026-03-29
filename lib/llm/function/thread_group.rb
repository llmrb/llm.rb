# frozen_string_literal: true

class LLM::Function
  ##
  # The {LLM::Function::ThreadGroup} class wraps an array of
  # {Thread} objects that are running {LLM::Function} calls
  # concurrently. It provides a single {#wait} method that
  # collects the {LLM::Function::Return} values from those
  # threads.
  #
  # This class is returned by {LLM::Function::Array#spawn}
  # when you call `ses.functions.spawn` on the collection
  # returned by {LLM::Session#functions}. It is a lightweight
  # wrapper that does not inherit from Ruby's built-in
  # {::ThreadGroup}.
  #
  # @example
  #   llm = LLM.openai(key: ENV["KEY"])
  #   ses = LLM::Session.new(llm, tools: [Weather, News, Stocks])
  #   ses.talk "Summarize the weather, headlines, and stock price."
  #   grp = ses.functions.spawn
  #   # do other work while tools run...
  #   ses.talk(grp.wait)
  #
  # @see LLM::Function::Array#spawn
  # @see LLM::Function::Array#wait
  class ThreadGroup
    ##
    # Creates a new {LLM::Function::ThreadGroup} from an array
    # of {Thread} objects.
    #
    # @param [Array<Thread>] threads
    #   An array of threads, each running an {LLM::Function#spawn}
    #   call. The thread's {Thread#value} will be an
    #   {LLM::Function::Return}.
    #
    # @return [LLM::Function::ThreadGroup]
    #   Returns a new thread group.
    def initialize(threads)
      @threads = threads
    end

    ##
    # Waits for all threads in the group to finish and returns
    # their {LLM::Function::Return} values.
    #
    # This method blocks until every thread in the group has
    # completed. If a thread raised an exception, the exception
    # is caught and wrapped in an {LLM::Function::Return} with
    # error information.
    #
    # @example
    #   llm = LLM.openai(key: ENV["KEY"])
    #   ses = LLM::Session.new(llm, tools: [Weather, News, Stocks])
    #   ses.talk "Summarize the weather, headlines, and stock price."
    #   grp = ses.functions.spawn
    #   returns = grp.wait
    #   # returns is now an array of LLM::Function::Return objects
    #   ses.talk(returns)
    #
    # @return [Array<LLM::Function::Return>]
    #   Returns an array of function return values, in the same
    #   order as the original threads.
    def wait
      @threads.map(&:value)
    end
  end
end