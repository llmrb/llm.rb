# frozen_string_literal: true

module LLM
  ##
  # The {LLM::Tracer LLM::Tracer} is the superclass of all
  # LLM tracers. It can be helpful for implementing instrumentation
  # and hooking into the lifecycle of an LLM request. See
  # {LLM::Tracer::Telemetry LLM::Tracer::Telemetry} for an
  # example tracer implementation.
  class Tracer
    require_relative "tracer/telemetry"
    require_relative "tracer/null"

    ##
    # @param [LLM::Provider] provider
    #  A provider
    def initialize(provider, options = {})
      @provider = provider
      @options = {}
    end

    ##
    # Called before an LLM provider request is executed.
    # @param [String] operation
    # @param [String] model
    # @return [void]
    def on_request_start(operation:, model:)
      raise NotImplementedError, "#{self.class} does not implement '#{__method__}'"
    end

    ##
    # Called after an LLM provider request succeeds.
    # @param [String] operation
    # @param [String] model
    # @param [LLM::Response] res
    # @param [Object, nil] span
    # @return [void]
    def on_request_finish(operation:, model:, res:, span: nil)
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
    # @param [String, nil] id
    #  The tool call ID assigned by the model/provider, if available.
    # @param [String, nil] name
    #  The tool (function) name.
    # @param [Hash, nil] arguments
    #  The parsed tool arguments.
    # @return [void]
    def on_tool_start(id:, name:, arguments:)
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
