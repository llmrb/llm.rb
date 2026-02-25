# frozen_string_literal: true

module LLM
  ##
  # The {LLM::Tracer LLM::Tracer} is the superclass of all
  # LLM tracers. It can be helpful for implementing instrumentation
  # and hooking into the lifecycle of an LLM request. See
  # {LLM::Tracer::Telemetry LLM::Tracer::Telemetry}, and
  # {LLM::Tracer::Logger LLM::Tracer::Logger} for example
  # tracer implementations.
  class Tracer
    require_relative "tracer/logger"
    require_relative "tracer/telemetry"
    require_relative "tracer/null"

    ##
    # @param [LLM::Provider] provider
    #  A provider
    # @param [Hash] options
    #  A hash of options
    def initialize(provider, options = {})
      @provider = provider
      @options = {}
    end

    ##
    # Called at the start of a conversation turn/generation.
    # This creates a parent span that will contain all operations
    # (chat, retrieval, tools) for this turn.
    # @param [String] model
    # @param [Hash] input
    # @return [Object, nil] generation_span
    def on_generation_start(model: nil, input: nil)
      nil
    end

    ##
    # Called when a conversation turn/generation completes successfully.
    # @param [Object, nil] generation_span
    # @param [LLM::Response] res
    # @param [String] model
    # @return [void]
    def on_generation_finish(generation_span: nil, res: nil, model: nil)
      nil
    end

    ##
    # Called when a conversation turn/generation fails.
    # @param [Object, nil] generation_span
    # @param [Exception] ex
    # @return [void]
    def on_generation_error(generation_span: nil, ex: nil)
      nil
    end

    ##
    # Called before an LLM provider request is executed.
    # @param [String] operation
    # @param [String] model
    # @param [Object, nil] parent_span
    # @return [void]
    def on_request_start(operation:, model: nil, parent_span: nil)
      raise NotImplementedError, "#{self.class} does not implement '#{__method__}'"
    end

    ##
    # Called after an LLM provider request succeeds.
    # @param [String] operation
    # @param [String] model
    # @param [LLM::Response] res
    # @param [Object, nil] span
    # @return [void]
    def on_request_finish(operation:, res:, model: nil, span: nil)
      raise NotImplementedError, "#{self.class} does not implement '#{__method__}'"
    end

    ##
    # Called when an LLM provider request fails.
    # @param [LLM::Error] ex
    # @param [Object, nil] span
    # @return [void]
    def on_request_error(ex:, span:)
      raise NotImplementedError, "#{self.class} does not implement '#{__method__}'"
    end

    ##
    # Called before a local tool/function executes.
    # @param [String] id
    #  The tool call ID assigned by the model/provider
    # @param [String] name
    #  The tool (function) name.
    # @param [Hash] arguments
    #  The parsed tool arguments.
    # @param [String] model
    #  The model name
    # @param [Object, nil] parent_span
    #  The parent span to nest this tool span under
    # @return [void]
    def on_tool_start(id:, name:, arguments:, model:, parent_span: nil)
      raise NotImplementedError, "#{self.class} does not implement '#{__method__}'"
    end

    ##
    # Called after a local tool/function succeeds.
    # @param [LLM::Function::Return] result
    #  The tool return object.
    # @param [Object, nil] span
    #  The span/context object returned by {#on_tool_start}.
    # @return [void]
    def on_tool_finish(result:, span:)
      raise NotImplementedError, "#{self.class} does not implement '#{__method__}'"
    end

    ##
    # Called when a local tool/function raises.
    # @param [Exception] ex
    #  The raised error.
    # @param [Object, nil] span
    #  The span/context object returned by {#on_tool_start}.
    # @return [void]
    def on_tool_error(ex:, span:)
      raise NotImplementedError, "#{self.class} does not implement '#{__method__}'"
    end

    ##
    # @return [String]
    def inspect
      "#<#{self.class.name}:0x#{object_id.to_s(16)} @provider=#{@provider.class} @tracer=#{@tracer.inspect}>"
    end

    ##
    # @return [Array]
    def spans
      []
    end

    ##
    # Flush the tracer
    # @note
    #  This method is only implemented by the {LLM::Tracer::Telemetry} tracer.
    #  It is a noop for other tracers.
    # @return [nil]
    def flush!
      nil
    end

    private

    ##
    # @return [String]
    def provider_name
      @provider.class.name.split("::").last.downcase
    end

    ##
    # @return [String]
    def provider_host
      @provider.instance_variable_get(:@host)
    end

    ##
    # @return [String]
    def provider_port
      @provider.instance_variable_get(:@port)
    end
  end
end
