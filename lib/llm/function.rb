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
  require_relative "function/tracing"
  prepend LLM::Function::Tracing

  class Return < Struct.new(:id, :name, :value)
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
  # @return [void]
  def params
    if block_given?
      if @params
        @params.merge!(yield(@schema))
      else
        @params = yield(@schema)
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
    runner = ((Class === @runner) ? @runner.new : @runner)
    Return.new(id, name, runner.call(**arguments))
  ensure
    @called = true
  end

  ##
  # Returns a value that communicates that the function call was cancelled
  # @example
  #   llm = LLM.openai(key: ENV["KEY"])
  #   ses = LLM::Session.new(llm, tools: [fn1, fn2])
  #   ses.talk "I want to run the functions"
  #   ses.talk ses.functions.map(&:cancel)
  # @return [LLM::Function::Return]
  def cancel(reason: "function call cancelled")
    Return.new(id, name, {cancelled: true, reason:})
  ensure
    @cancelled = true
  end

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
  # @return [Hash]
  def adapt(provider)
    case provider.class.to_s
    when "LLM::Gemini"
      {name: @name, description: @description, parameters: @params}.compact
    when "LLM::Anthropic"
      {name: @name, description: @description, input_schema: @params}.compact
    else
      format_openai(provider)
    end
  end

  def format_openai(provider)
    case provider.class.to_s
    when "LLM::OpenAI::Responses"
      {
        type: "function", name: @name, description: @description,
        parameters: @params.to_h.merge(additionalProperties: false), strict: true
      }.compact
    else
      {
        type: "function", name: @name,
        function: {name: @name, description: @description, parameters: @params}
      }.compact
    end
  end
end
