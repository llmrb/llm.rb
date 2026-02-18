# frozen_string_literal: true

module LLM
  ##
  # A no-op tracer that ignores all tracing callbacks.
  class Tracer::Null < Tracer
    ##
    # @param [Hash] payload
    # @return [nil]
    def on_request_start(**)
      nil
    end

    ##
    # @param [Hash] payload
    # @return [nil]
    def on_request_finish(**)
      nil
    end

    ##
    # @param [Hash] payload
    # @return [nil]
    def on_request_error(**)
      nil
    end

    ##
    # @param [Hash] payload
    # @return [nil]
    def on_tool_start(**)
      nil
    end

    ##
    # @param [Hash] payload
    # @return [nil]
    def on_tool_finish(**)
      nil
    end

    ##
    # @param [Hash] payload
    # @return [nil]
    def on_tool_error(**)
      nil
    end
  end
end
