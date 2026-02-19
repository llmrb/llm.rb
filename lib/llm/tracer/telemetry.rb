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
  #   llm = LLM.openai(token: ENV["KEY"], tracer: :telemetry)
  #   bot = LLM::Bot.chat(llm)
  #   bot.chat "hello"
  #   bot.chat "how are you?"
  #   bot.tracer.spans.each { pp span }
  class Tracer::Telemetry < Tracer
    ##
    # param [LLM::Provider] provider
    #  An LLM provider
    # @return [Tracer]
    def initialize(provider)
      @provider = provider
      setup!
    end

    ##
    # see (LLM::Tracer#on_request_start)
    def on_request_start(operation:, model:)
      return nil unless operation == "chat"
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

    ##
    # see (LLM::Tracer#on_request_finish)
    def on_request_finish(operation:, model:, res:, span: nil)
      return nil unless operation == "chat"
      attributes = {
        "gen_ai.operation.name" => operation,
        "gen_ai.request.model" => model,
        "gen_ai.response.id" => res.id,
        "gen_ai.response.model" => model,
        "gen_ai.usage.input_tokens" => res.usage.input_tokens,
        "gen_ai.usage.output_tokens" => res.usage.output_tokens
      }.compact.merge!(finish_attributes(res))
      attributes.each { span.set_attribute(_1, _2) }
      span.add_event("gen_ai.request.finish")
      span.tap(&:finish)
    end

    ##
    # (see LLM::Tracer#on_request_error)
    def on_request_error(ex:, span:)
      return nil unless span
      attributes = {"error.type" => ex.class.to_s}.compact
      attributes.each { span.set_attribute(_1, _2) }
      span.add_event("gen_ai.request.finish")
      span.status = ::OpenTelemetry::Trace::Status.error(ex.message)
      span.tap(&:finish)
    end

    ##
    # @return [Array<OpenTelemetry::SDK::Trace::SpanData>]
    def spans
      ::OpenTelemetry.tracer_provider.force_flush
      @exporter.finished_spans
    end

    private

    ##
    # @param [LLM::Response] res
    # @api private
    def finish_attributes(res)
      case @provider.class.to_s
      when "LLM::OpenAI"
        {
          "openai.response.service_tier" => res.service_tier,
          "openai.response.system_fingerprint" => res.system_fingerprint
        }
      else {}
      end
    end

    ##
    # @api private
    def setup!
      require "opentelemetry/sdk" unless defined?(OpenTelemetry)
      @exporter = OpenTelemetry::SDK::Trace::Export::InMemorySpanExporter.new
      OpenTelemetry::SDK.configure do |c|
        c.add_span_processor(
          OpenTelemetry::SDK::Trace::Export::BatchSpanProcessor.new(@exporter)
        )
      end
      @tracer = OpenTelemetry.tracer_provider.tracer("llm.rb", LLM::VERSION)
    end
  end
end
