# frozen_string_literal: true

class LLM::Function
  ##
  # The {LLM::Function::Ractor::Task} class wraps a ractor-backed function
  # call and delegates mailbox coordination to
  # {LLM::Function::Ractor::Mailbox}.
  class Ractor::Task
    ##
    # @return [LLM::Function::Ractor::Mailbox]
    attr_reader :mailbox

    ##
    # @param [Class] runner_class
    # @param [String, nil] id
    # @param [String] name
    # @param [Hash, Array, nil] arguments
    # @param [LLM::Tracer, nil] tracer
    # @param [Object, nil] span
    # @return [LLM::Function::Ractor::Task]
    def initialize(runner_class, id, name, arguments, tracer: nil, span: nil)
      @runner_class = runner_class
      @id = id
      @name = name
      @arguments = arguments
      @tracer = tracer
      @span = span
    end

    ##
    # @return [LLM::Function::Ractor::Task]
    def spawn
      @mailbox = Ractor::Mailbox.new(build_task)
      self
    end

    ##
    # @return [Boolean]
    def alive?
      mailbox.alive?
    end

    ##
    # @return [nil]
    def interrupt!
      nil
    end
    alias_method :cancel!, :interrupt!

    ##
    # @return [LLM::Function::Return]
    def wait
      id, name, value = mailbox.wait
      result = Return.new(id, name, value)
      @tracer&.on_tool_finish(result:, span: @span)
      result
    end
    alias_method :value, :wait

    ##
    # @return [Class]
    def group_class
      LLM::Function::Ractor::Group
    end

    private

    def build_task
      ::Ractor.new(@runner_class, @id, @name, @arguments) do |runner_class, id, name, arguments|
        LLM::Function::Ractor::Job.new(::Ractor.current, runner_class, id, name, arguments).call
      end
    end
  end
end
