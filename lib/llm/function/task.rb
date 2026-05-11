# frozen_string_literal: true

class LLM::Function
  ##
  # The {LLM::Function::Task} class wraps a single concurrent function call and
  # provides a small, uniform interface across threads, scheduler-backed fibers,
  # and async tasks.
  class Task
    ##
    # @return [Object]
    attr_reader :task

    ##
    # @return [LLM::Function, nil]
    attr_reader :function

    ##
    # @param [Thread, Fiber, Async::Task, Ractor, LLM::Function::Ractor::Task] task
    # @param [LLM::Function, nil] function
    # @return [LLM::Function::Task]
    def initialize(task, function = nil)
      @task = task
      @function = function
    end

    ##
    # @return [Boolean]
    def alive?
      return task.alive? if task.respond_to?(:alive?)
      false
    end

    ##
    # @return [nil]
    def interrupt!
      task.interrupt! if task.respond_to?(:interrupt!)
      function&.interrupt!
      nil
    end
    alias_method :cancel!, :interrupt!

    ##
    # @return [LLM::Function::Return]
    def wait
      if Thread === task
        task.value
      elsif Fiber === task
        fiber.alive? ? scheduler.run : nil
        task.value
      else
        task.wait
      end
    end
    alias_method :value, :wait

    ##
    # @return [Class]
    def group_class
      case task
      when Thread then LLM::Function::ThreadGroup
      when Fiber then LLM::Function::FiberGroup
      else LLM::Function::TaskGroup
      end
    end

    private

    def scheduler
      Fiber.scheduler
    end
  end
end
