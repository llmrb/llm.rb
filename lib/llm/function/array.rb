# frozen_string_literal: true

class LLM::Function
  ##
  # The {LLM::Function::Array} module extends the array
  # returned by {LLM::Context#functions} with methods
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
    # This method returns an execution group that can be
    # waited on to access the return values.
    #
    # @param [Symbol] strategy
    #   Controls concurrency strategy:
    #   - `:call`: Call functions sequentially without spawning
    #   - `:thread`: Use threads
    #   - `:task`: Use async tasks (requires async gem)
    #   - `:fiber`: Use scheduler-backed fibers (requires Fiber.scheduler)
    #   - `:fork`: Use forked child processes
    #   - `:ractor`: Use Ruby ractors (class-based tools only; MCP tools are not supported)
    #
    # @return [LLM::Function::CallGroup, LLM::Function::ThreadGroup, LLM::Function::TaskGroup, LLM::Function::FiberGroup, LLM::Function::Ractor::Group]
    def spawn(strategy)
      case strategy
      when :call
        CallGroup.new(self)
      when :task
        TaskGroup.new(map { |fn| fn.spawn(:task) })
      when :thread
        ThreadGroup.new(map { |fn| fn.spawn(:thread) })
      when :fiber
        FiberGroup.new(map { |fn| fn.spawn(:fiber) })
      when :fork
        Fork::Group.new(map { |fn| fn.spawn(:fork) })
      when :ractor
        Ractor::Group.new(map { |fn| fn.spawn(:ractor) })
      else
        raise ArgumentError, "Unknown strategy: #{strategy.inspect}. Expected :call, :thread, :task, :fiber, :fork, or :ractor"
      end
    end

    ##
    # Calls all functions in a collection concurrently
    # and waits for the return values.
    #
    # @param [Symbol] strategy
    #   Controls concurrency strategy:
    #   - `:call`: Call each function sequentially through a call group
    #   - `:thread`: Use threads
    #   - `:task`: Use async tasks (requires async gem)
    #   - `:fiber`: Use scheduler-backed fibers (requires Fiber.scheduler)
    #   - `:fork`: Use forked child processes
    #   - `:ractor`: Use Ruby ractors (class-based tools only; MCP tools are not supported)
    #
    # @return [Array<LLM::Function::Return>]
    #  Returns values to be reported back to the LLM.
    def wait(strategy)
      spawn(strategy).wait
    end
  end
end
