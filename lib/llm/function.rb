# frozen_string_literal: true

##
# The {LLM::Function LLM::Function} class represents a local
# function that can be called by an LLM.
#
# @example example #1
#   LLM.function(:system) do |fn|
#     fn.name "system"
#     fn.description "Runs system commands"
#     fn.params do |schema|
#       schema.object(command: schema.string.required)
#     end
#     fn.define do |command:|
#       {success: Kernel.system(command)}
#     end
#   end
#
# @example example #2
#   class System < LLM::Tool
#     name "system"
#     description "Runs system commands"
#     params do |schema|
#       schema.object(command: schema.string.required)
#     end
#
#     def call(command:)
#       {success: Kernel.system(command)}
#     end
#   end
class LLM::Function
  require_relative "function/registry"
  require_relative "function/tracing"
  require_relative "function/array"
  require_relative "function/call_group"
  require_relative "function/task"
  require_relative "function/thread_group"
  require_relative "function/fiber_group"
  require_relative "function/task_group"
  require_relative "function/fork"
  require_relative "function/fork_group"
  require_relative "function/ractor"
  require_relative "function/ractor_group"

  extend LLM::Function::Registry
  prepend LLM::Function::Tracing

  ##
  # {LLM::Function::Return LLM::Function::Return} represents the result of a
  # tool call.
  #
  # In llm.rb, tool execution is not complete until the requested function is
  # answered with a return object and that return is sent back through the
  # context. This is the object that closes that loop.
  #
  # The return carries:
  # - the tool call ID
  # - the tool name
  # - the tool's return value
  #
  # That value is usually a `Hash`, but it can be any JSON-like structure your
  # tool returns. `LLM::Function#call` produces one automatically, and
  # `LLM::Function#cancel` produces one that represents a cancelled tool call.
  #
  # You can also construct one directly when you need to intercept, scrub, or
  # synthesize a tool return before sending it back to the model.
  #
  # @example Returning a normal tool result
  #   ret = LLM::Function::Return.new("call_1", "weather", {forecast: "sunny"})
  #   ctx.talk(ret)
  #
  # @example Returning a tool result after rewriting its payload
  #   value = ret.value.merge(email: "[REDACTED_EMAIL]")
  #   ctx.talk(LLM::Function::Return.new(ret.id, ret.name, value))
  Return = Struct.new(:id, :name, :value) do
    ##
    # Returns true when the return value represents an error.
    # @return [Boolean]
    def error?
      Hash === value && value[:error] == true
    end

    ##
    # Returns a Hash representation of {LLM::Function::Return}
    # @return [Hash]
    def to_h
      {id:, name:, value:}
    end

    ##
    # @return [String]
    def to_json(...)
      LLM.json.dump(to_h, ...)
    end

    ##
    # @return [nil]
    def interrupt!
      nil
    end
    alias_method :cancel!, :interrupt!
  end

  ##
  # Returns the function ID
  # @return [String, nil]
  attr_accessor :id

  ##
  # Returns function arguments
  # @return [Array, nil]
  attr_accessor :arguments

  ##
  # Returns a tracer, or nil
  # @return [LLM::Tracer, nil]
  attr_accessor :tracer

  ##
  # Returns a model name, or nil
  # @return [String, nil]
  attr_accessor :model

  ##
  # @param [String] name The function name
  # @yieldparam [LLM::Function] self The function object
  def initialize(name, &b)
    @name = name
    @schema = LLM::Schema.new
    @called = false
    @cancelled = false
    yield(self) if block_given?
  end

  ##
  # Set (or get) the function name
  # @param [String] name The function name
  # @return [void]
  def name(name = nil)
    if name
      @name = name.to_s
    else
      @name
    end
  end

  ##
  # Set (or get) the function description
  # @param [String] desc The function description
  # @return [void]
  def description(desc = nil)
    if desc
      @description = desc
    else
      @description
    end
  end

  ##
  # Set (or get) the function parameters
  # @yieldparam [LLM::Schema] schema The schema object
  # @return [LLM::Schema::Leaf, nil]
  def params
    if block_given?
      params = yield(@schema)
      params = LLM::Schema.parse(params) if Hash === params
      if @params
        @params.merge!(params)
      else
        @params = params
      end
    else
      @params
    end
  end

  ##
  # Set the function implementation
  # @param [Proc, Class] b The function implementation
  # @return [void]
  def define(klass = nil, &b)
    @runner = klass || b
  end
  alias_method :register, :define

  ##
  # Call the function
  # @return [LLM::Function::Return] The result of the function call
  def call
    call_function
  ensure
    @called = true
  end

  ##
  # Calls the function concurrently.
  #
  # This is the low-level method that powers concurrent tool execution.
  # Prefer the collection methods on {LLM::Context#functions} for most
  # use cases: {LLM::Function::Array#call}, {LLM::Function::Array#wait},
  # or {LLM::Function::Array#spawn}.
  #
  # @example
  #   # Normal usage (via collection)
  #   ctx.talk(ctx.functions.wait)
  #
  #   # Direct usage (uncommon)
  #   task = tool.spawn(:thread)
  #   result = task.value
  #
  # @param [Symbol] strategy
  #   Controls concurrency strategy:
  #   - `:thread`: Use threads
  #   - `:task`: Use async tasks (requires async gem)
  #   - `:fork`: Use a forked child process (requires xchan.rb support)
  #   - `:fiber`: Use scheduler-backed fibers (requires Fiber.scheduler)
  #   - `:fork`: Use a forked child process (requires xchan.rb support)
  #   - `:ractor`: Use Ruby ractors (class-based tools only; MCP tools are not supported)
  #
  # @return [LLM::Function::Task]
  #   Returns a task whose `#value` is an {LLM::Function::Return}.
  def spawn(strategy)
    task = case strategy
    when :task
      LLM.require "async" unless defined?(::Async)
      Async { call! }
    when :thread
      Thread.new { call! }
    when :fiber
      raise ArgumentError, "Fiber concurrency requires Fiber.scheduler" unless Fiber.scheduler
      Fiber.schedule { call! }
    when :fork
      LLM.require "xchan" unless defined?(::Chan::UNIXSocket)
      span = @tracer&.on_tool_start(id:, name:, arguments:, model:)
      Fork::Task.new(self, tracer: @tracer, span:).spawn
    when :ractor
      raise LLM::RactorError, "Ractor concurrency only supports class-based tools" unless Class === @runner
      if @runner.respond_to?(:skill?) && @runner.skill?
        raise LLM::RactorError, "Ractor concurrency does not support skill-backed tools"
      end
      span = @tracer&.on_tool_start(id:, name:, arguments:, model:)
      Ractor::Task.new(@runner, id, name, arguments, tracer: @tracer, span:).spawn
    else
      raise ArgumentError, "Unknown strategy: #{strategy.inspect}. Expected :thread, :task, :fiber, :fork, or :ractor"
    end
    Task.new(task, self)
  ensure
    @called = true
  end

  ##
  # Returns a value that communicates that the function call was cancelled
  # @example
  #   llm = LLM.openai(key: ENV["KEY"])
  #   ctx = LLM::Context.new(llm, tools: [fn1, fn2])
  #   ctx.talk "I want to run the functions"
  #   ctx.talk ctx.functions.map(&:cancel)
  # @return [LLM::Function::Return]
  def cancel(reason: "function call cancelled")
    Return.new(id, name, {cancelled: true, reason:})
  ensure
    @cancelled = true
  end

  ##
  # Notifies the function runner that the call was interrupted.
  # This is cooperative and only applies to runners that implement
  # `on_interrupt`.
  # @return [nil]
  def interrupt!
    hook = %i[on_cancel on_interrupt].find { @runner.respond_to?(_1) }
    @runner.public_send(hook) if hook
    nil
  end
  alias_method :cancel!, :interrupt!

  ##
  # Returns true when a function has been called
  # @return [Boolean]
  def called?
    @called
  end

  ##
  # Returns true when a function has been cancelled
  # @return [Boolean]
  def cancelled?
    @cancelled
  end

  ##
  # Returns true when a function has neither been called nor cancelled
  # @return [Boolean]
  def pending?
    !@called && !@cancelled
  end

  ##
  # Returns an in-band error for an unresolved function call.
  # @return [LLM::Function::Return]
  def unavailable
    Return.new(id, name, {
      error: true,
      type: LLM::NoSuchToolError.name,
      message: "tool not found"
    })
  end

  ##
  # @return [Hash]
  def adapt(provider)
    case provider.class.to_s
    when "LLM::Google"
      {name: @name, description: @description, parameters: @params}.compact
    when "LLM::Anthropic"
      {
        name: @name,
        description: @description,
        input_schema: @params || {type: "object", properties: {}}
      }.compact
    else
      format_openai(provider)
    end
  end

  ##
  # Returns the bound function runner instance.
  # @return [Object]
  def runner
    runner = Class === @runner ? @runner.new : @runner
    runner.tracer = @tracer if runner.respond_to?(:tracer=)
    runner
  end

  private

  def format_openai(provider)
    case provider.class.to_s
    when "LLM::OpenAI::Responses"
      {
        type: "function", name: @name, description: @description,
        parameters: (@params || {type: "object", properties: {}}).to_h.merge(additionalProperties: false), strict: false
      }.compact
    else
      params = @params || {type: "object", properties: {}}
      {
        type: "function", name: @name,
        function: {name: @name, description: @description, parameters: params}
      }.compact
    end
  end

  ##
  # Internal method that calls the function and returns a Return object.
  # Handles both class-based and proc-based runners, and rescues exceptions.
  #
  # @return [LLM::Function::Return]
  #   Returns a Return object with either the function result or error information.
  def call_function
    runner = self.runner
    kwargs = Hash === arguments ? arguments.transform_keys(&:to_sym) : arguments
    Return.new(id, name, runner.call(**kwargs))
  rescue => ex
    Return.new(id, name,  {error: true, type: ex.class.name, message: ex.message})
  end

  def call!
    llm = @tracer&.llm
    return call unless llm.respond_to?(:with_tracer)
    llm.with_tracer(@tracer) { call }
  end
end
