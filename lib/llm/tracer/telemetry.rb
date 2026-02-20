# frozen_string_literal: true

module LLM
  ##
  # The {LLM::Tracer::Telemetry LLM::Tracer::Telemetry} tracer provides
  # telemetry support through the [opentelemetry-ruby](https://github.com/open-telemetry/opentelemetry-ruby)
  # RubyGem. The gem should be installed separately since this feature is opt-in
  # and disabled by default. This feature exists to support integration with tools
  # like [LangSmith](https://www.langsmith.com).
  #
  # @see https://github.com/open-telemetry/semantic-conventions/blob/main/docs/gen-ai Telemetry specs (index)
  # @see https://github.com/open-telemetry/semantic-conventions/blob/main/docs/gen-ai/openai.md Telemetry specs (OpenAI)
  #
  # @example
  #   #!/usr/bin/env ruby
  #   require "llm"
  #   require "pp"
  #
  #   llm = LLM.openai(key: ENV["KEY"])
  #   llm.tracer = LLM::Tracer::Telemetry.new(llm)
  #
  #   bot = LLM::Bot.new(llm)
  #   bot.chat "hello"
  #   bot.chat "how are you?"
  #   bot.tracer.spans.each { |span| pp span }
  class Tracer::Telemetry < Tracer
    ##
    # param [LLM::Provider] provider
    #  An LLM provider
    # @return [LLM::Tracer::Telemetry]
    def initialize(provider, options = {})
      super
      setup!
    end

    ##
    # @param (see LLM::Tracer#on_request_start)
    def on_request_start(operation:, model:)
      case operation
      when "chat" then start_chat(operation:, model:)
      when "retrieval" then start_retrieval(operation:)
      else nil
      end
    end

    ##
    # @param (see LLM::Tracer#on_request_finish)
    def on_request_finish(operation:, model:, res:, span: nil)
      return nil unless span
      case operation
      when "chat" then finish_chat(operation:, model:, res:, span:)
      when "retrieval" then finish_retrieval(operation:, res:, span:)
      else nil
      end
    end

    ##
    # @param (see LLM::Tracer#on_request_error)
    def on_request_error(ex:, span:)
      return nil unless span
      attributes = {"error.type" => ex.class.to_s}.compact
      attributes.each { span.set_attribute(_1, _2) }
      span.add_event("gen_ai.request.finish")
      span.status = ::OpenTelemetry::Trace::Status.error(ex.message)
      span.tap(&:finish)
    end

    ##
    # @param (see LLM::Tracer#on_tool_start)
    # @return (see LLM::Tracer#on_tool_start)
    def on_tool_start(id:, name:, arguments:)
      attributes = {
        "gen_ai.operation.name" => "execute_tool",
        "gen_ai.tool.call.id" => id,
        "gen_ai.tool.name" => name,
        "gen_ai.tool.call.arguments" => LLM.json.dump(arguments),
        "gen_ai.provider.name" => provider_name,
        "server.address" => provider_host,
        "server.port" => provider_port
      }.compact
      span_name = ["execute_tool", name].compact.join(" ")
      span = @tracer.start_span(span_name.empty? ? "gen_ai.tool" : span_name, kind: :client, attributes:)
      span.add_event("gen_ai.tool.start")
      span
    end

    ##
    # @param (see LLM::Tracer#on_tool_finish)
    # @return (see LLM::Tracer#on_tool_finish)
    def on_tool_finish(result:, span:)
      return nil unless span
      attributes = {
        "gen_ai.tool.call.id" => result.id,
        "gen_ai.tool.name" => result.name,
        "gen_ai.tool.call.result" => LLM.json.dump(result.value)
      }.compact
      attributes.each { span.set_attribute(_1, _2) }
      span.add_event("gen_ai.tool.finish")
      span.tap(&:finish)
    end

    ##
    # @param (see LLM::Tracer#on_tool_error)
    # @return (see LLM::Tracer#on_tool_error)
    def on_tool_error(ex:, span:)
      return nil unless span
      attributes = {"error.type" => ex.class.to_s}.compact
      attributes.each { span.set_attribute(_1, _2) }
      span.add_event("gen_ai.tool.finish")
      span.status = ::OpenTelemetry::Trace::Status.error(ex.message)
      span.tap(&:finish)
    end

    ##
    # @return [Array<OpenTelemetry::SDK::Trace::SpanData>]
    def spans
      @tracer_provider.force_flush
      @exporter.finished_spans
    end

    private

    ##
    # @api private
    def setup!
      require "opentelemetry/sdk" unless defined?(OpenTelemetry)
      @exporter = OpenTelemetry::SDK::Trace::Export::InMemorySpanExporter.new
      processor = OpenTelemetry::SDK::Trace::Export::BatchSpanProcessor.new(@exporter)
      @tracer_provider = OpenTelemetry::SDK::Trace::TracerProvider.new
      @tracer_provider.add_span_processor(processor)
      @tracer = @tracer_provider.tracer("llm.rb", LLM::VERSION)
    end

    ##
    # @param [String] operation
    # @param [LLM::Response] res
    # @api private
    def finish_attributes(operation, res)
      case @provider.class.to_s
      when "LLM::OpenAI" then openai_attributes(operation, res)
      else {}
      end
    end

    ##
    # @param [String] operation
    # @param [LLM::Response] res
    # @api private
    def openai_attributes(operation, res)
      case operation
      when "chat"
        {
          "openai.response.service_tier" => res.service_tier,
          "openai.response.system_fingerprint" => res.system_fingerprint
        }
      when "retrieval"
        {
          "openai.vector_store.search.result_count" => res.size,
          "openai.vector_store.search.has_more" => res.has_more
        }
      else {}
      end
    end

    ##
    # start_*

    def start_chat(operation:, model:)
      attributes = {
        "gen_ai.operation.name" => operation,
        "gen_ai.request.model" => model,
        "gen_ai.provider.name" => provider_name,
        "server.address" => provider_host,
        "server.port" => provider_port
      }.compact
      span_name = [operation, model].compact.join(" ")
      span = @tracer.start_span(span_name.empty? ? "gen_ai.request" : span_name, kind: :client, attributes:)
      span.add_event("gen_ai.request.start")
      span
    end

    def start_retrieval(operation:)
      attributes = {
        "gen_ai.operation.name" => operation,
        "gen_ai.provider.name" => provider_name,
        "server.address" => provider_host,
        "server.port" => provider_port
      }.compact
      span = @tracer.start_span(operation, kind: :client, attributes:)
      span.add_event("gen_ai.request.start")
      span
    end

    ##
    # finish_*

    def finish_chat(operation:, model:, res:, span:)
      attributes = {
        "gen_ai.operation.name" => operation,
        "gen_ai.request.model" => model,
        "gen_ai.response.id" => res.id,
        "gen_ai.response.model" => model,
        "gen_ai.usage.input_tokens" => res.usage.input_tokens,
        "gen_ai.usage.output_tokens" => res.usage.output_tokens
      }.merge!(finish_attributes(operation, res)).compact
      attributes.each { span.set_attribute(_1, _2) }
      span.add_event("gen_ai.request.finish")
      span.tap(&:finish)
    end

    def finish_retrieval(operation:, res:, span:)
      attributes = {
        "gen_ai.operation.name" => operation
      }.merge!(finish_attributes(operation, res)).compact
      attributes.each { span.set_attribute(_1, _2) }
      span.add_event("gen_ai.request.finish")
      span.tap(&:finish)
    end
  end
end
