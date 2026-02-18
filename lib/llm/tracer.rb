# frozen_string_literal: true

module LLM
  ##
  # Abstract base class for request/tool tracing hooks.
  # Subclasses should override one or more +on_*+ methods.
  class Tracer
    require_relative "tracer/telemetry"
    require_relative "tracer/null"

    ##
    # @param [LLM::Provider] provider
    #  A provider
    def initialize(provider)
      @provider = provider
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
    # @param [Hash] payload
    # @return [void]
    def on_tool_start(payload = {})
      raise NotImplementedError, "#{self.class} does not implement '#{__method__}'"
    end

    ##
    # Called after a local tool/function succeeds.
    # @param [Hash] payload
    # @return [void]
    def on_tool_finish(payload = {})
      raise NotImplementedError, "#{self.class} does not implement '#{__method__}'"
    end

    ##
    # Called when a local tool/function raises.
    # @param [Hash] payload
    # @return [void]
    def on_tool_error(payload = {})
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
