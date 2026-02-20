# frozen_string_literal: true

module LLM
  ##
  # The {LLM::Tracer::Logger LLM::Tracer::Logger} class provides a
  # tracer that provides logging facilities through Ruby's
  # standard library.
  #
  # @example
  #   llm = LLM.openai(key: ENV["KEY"])
  #   # Log to a file
  #   llm.tracer = LLM::Tracer::Logger.new(llm, file: "/tmp/log.txt")
  #   # Log to $stdout (default)
  #   llm.tracer = LLM::Tracer::Logger.new(llm, file: $stdout)
  class Tracer::Logger < Tracer
    ##
    # @param (see LLM::Tracer#initialize)
    def initialize(provider, options = {})
      super
      setup!(**options)
    end

    ##
    # @param (see LLM::Tracer#on_request_start)
    # @return [void]
    def on_request_start(operation:, model:)
      @logger.info(
        tracer: "llm.rb (logger)",
        event: "request.start",
        provider: provider_name,
        operation:,
        model:
      )
    end

    ##
    # @param (see LLM::Tracer#on_request_finish)
    # @return [void]
    def on_request_finish(operation:, model:, res:, **)
      @logger.info(
        tracer: "llm.rb (logger)",
        event: "request.finish",
        provider: provider_name,
        response_id: res.id,
        input_tokens: res.usage.input_tokens,
        output_tokens: res.usage.output_tokens,
        operation:,
        model:
      )
    end

    ##
    # @param (see LLM::Tracer#on_request_error)
    # @return [void]
    def on_request_error(ex:, **)
      @logger.error(
        tracer: "llm.rb (logger)",
        event: "request.error",
        provider: provider_name,
        error_class: ex.class.to_s,
        error_message: ex.message
      )
    end

    ##
    # @param (see LLM::Tracer#on_tool_start)
    # @return [void]
    def on_tool_start(**)
      nil
    end

    ##
    # @param (see LLM::Tracer#on_tool_finish)
    # @return [void]
    def on_tool_finish(**)
      nil
    end

    ##
    # @param (see LLM::Tracer#on_tool_error)
    # @return [void]
    def on_tool_error(**)
      nil
    end

    private

    def setup!(file: $stdout)
      require "logger" unless defined?(::Logger)
      @logger = ::Logger.new(file)
    end
  end
end
