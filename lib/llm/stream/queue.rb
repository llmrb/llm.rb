# frozen_string_literal: true

class LLM::Stream
  ##
  # A small queue for collecting streamed tool work. Values can be immediate
  # {LLM::Function::Return} objects or concurrent handles returned by
  # {LLM::Function#spawn}. Calling {#wait} resolves queued work and
  # returns an array of {LLM::Function::Return} values.
  class Queue
    ##
    # @param [LLM::Stream] stream
    # @return [LLM::Stream::Queue]
    def initialize(stream)
      @stream = stream
      @items = []
    end

    ##
    # Enqueue a function return or spawned task.
    # @param [LLM::Function::Return, Thread, Async::Task, Fiber] item
    # @return [LLM::Stream::Queue]
    def <<(item)
      @items << item
      self
    end

    ##
    # Returns true when the queue is empty.
    # @return [Boolean]
    def empty?
      @items.empty?
    end

    ##
    # @return [nil]
    def interrupt!
      @items.each(&:interrupt!)
      nil
    end
    alias_method :cancel!, :interrupt!

    ##
    # Waits for queued work to finish and returns function results.
    #
    # Queued work is waited according to the actual task types that were
    # enqueued, so callers do not need to provide a strategy here.
    #
    # @return [Array<LLM::Function::Return>]
    def wait
      returns, tasks = @items.shift(@items.length).partition { LLM::Function::Return === _1 }
      results = wait_tasks(tasks)
      returns.concat fire_hooks(tasks, results)
    end
    alias_method :value, :wait

    private

    def wait_tasks(tasks)
      return [] if tasks.empty?
      strategies = tasks.map { task_strategy(_1) }.uniq
      return wait_group(tasks, strategies.first) unless strategies.length > 1
      grouped = strategies.to_h { [_1, []] }
      tasks.each do |task|
        grouped[task_strategy(task)] << task
      end
      strategies.flat_map do |name|
        selected = grouped.fetch(name)
        selected.empty? ? [] : wait_group(selected, name)
      end
    end

    def wait_group(tasks, strategy)
      case strategy
      when :thread then LLM::Function::ThreadGroup.new(tasks).wait
      when :task then LLM::Function::TaskGroup.new(tasks).wait
      when :fiber then LLM::Function::FiberGroup.new(tasks).wait
      when :fork then LLM::Function::Fork::Group.new(tasks).wait
      when :ractor then LLM::Function::Ractor::Group.new(tasks).wait
      else raise ArgumentError, "Unknown strategy: #{strategy.inspect}. Expected :thread, :task, :fiber, :fork, or :ractor"
      end
    end

    def task_strategy(task)
      case task.task
      when Thread then :thread
      when Fiber then :fiber
      when LLM::Function::Ractor::Task then :ractor
      when LLM::Function::Fork::Task then :fork
      else :task
      end
    end

    def fire_hooks(tasks, results)
      results.each_with_index do |result, idx|
        tool = tasks[idx]&.function
        @stream.on_tool_return(tool, result) if tool
      end
      results
    end
  end
end
