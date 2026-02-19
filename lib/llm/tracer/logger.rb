# frozen_string_literal: true

module LLM
  ##
  # The {Tracer::Logger Tracer::Logger} class provides a
  # tracer that provides logging facilities through Ruby's
  # standard library.
  #
  # @example
  #   LLM::Tracer::Logger.configure do |tracer|
  #     # Defaults to $stdout
  #     tracer.file = File.join(Dir.tmpdir, "log.txt")
  #   end
  class Tracer::Logger < Tracer
    ##
    # Defaults to standard output
    # @return [IO, String]
    def self.file
      @file || $stdout
    end

    ##
    # @param [IO, String] io
    #  An IO, or path to a file
    # @return [void]
    def self.file=(io)
      @file = io
    end

    ##
    # @param (see LLM::Tracer#initialize)
    def initialize(provider)
      @provider = provider
      setup!
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

    def setup!
      require "logger" unless defined?(::Logger)
      @logger = ::Logger.new(self.class.file)
    end
  end
end
