# frozen_string_literal: true

module LLM
  ##
  # The {LLM::Tracer::Telemetry LLM::Tracer::Telemetry} tracer provides
  # telemetry support through the [opentelemetry-ruby](https://github.com/open-telemetry/opentelemetry-ruby)
  # RubyGem. The gem should be installed separately since this feature is opt-in
  # and disabled by default. This feature exists to support integration with tools
  # like [LangSmith](https://www.langsmith.com).
  #
  # The tracer supports hierarchical spans similar to Langfuse, where generation-level
  # spans act as parents containing all operations (chat, retrieval, tools) for a
  # conversation turn.
  #
  # @see https://github.com/open-telemetry/semantic-conventions/blob/main/docs/gen-ai Telemetry specs (index)
  # @see https://github.com/open-telemetry/semantic-conventions/blob/main/docs/gen-ai/openai.md Telemetry specs (OpenAI)
  #
  # @example InMemory export
  #   #!/usr/bin/env ruby
  #   require "llm"
  #   require "pp"
  #
  #   llm = LLM.openai(key: ENV["KEY"])
  #   llm.tracer = LLM::Tracer::Telemetry.new(llm)
  #
  #   ses = LLM::Session.new(llm)
  #   ses.talk "hello"
  #   ses.talk "how are you?"
  #   ses.tracer.spans.each { |span| pp span }
  #
  # @example Hierarchical generation tracking
  #   #!/usr/bin/env ruby
  #   require "llm"
  #
  #   llm = LLM.openai(key: ENV["KEY"])
  #   llm.tracer = LLM::Tracer::Telemetry.new(llm)
  #
  #   # Start a generation span that will contain all operations
  #   generation_span = llm.tracer.on_generation_start(model: "gpt-4", input: "Hello")
  #   
  #   begin
  #     ses = LLM::Session.new(llm)
  #     response = ses.talk "hello"
  #     # All chat operations and tool calls are automatically nested under generation_span
  #     llm.tracer.on_generation_finish(generation_span:, res: response)
  #   rescue => ex
  #     llm.tracer.on_generation_error(generation_span:, ex:)
  #   end
  #
  # @example OTLP export
  #   #!/usr/bin/env ruby
  #   require "llm"
  #   require "opentelemetry-exporter-otlp"
  #
  #   endpoint = "https://api.smith.langchain.com/otel/v1/traces"
  #   exporter = OpenTelemetry::Exporter::OTLP::Exporter.new(endpoint:)
  #
  #   llm = LLM.openai(key: ENV["KEY"])
  #   llm.tracer = LLM::Tracer::Telemetry.new(llm, exporter:)
  #
  #   # Generation spans sent to LangSmith with nested operations
  #   generation_span = llm.tracer.on_generation_start(model: "gpt-4")
  #   ses = LLM::Session.new(llm)
  #   response = ses.talk "hello"
  #   llm.tracer.on_generation_finish(generation_span:, res: response)
  class Tracer::Telemetry < Tracer
    ##
    # param [LLM::Provider] provider
    #  An LLM provider
    # @return [LLM::Tracer::Telemetry]
    def initialize(provider, options = {})
      super
      @exporter = options.delete(:exporter)
      @current_generation = nil
      setup!
    end

    ##
    # @param (see LLM::Tracer#on_generation_start)
    def on_generation_start(model: nil, input: nil)
      attributes = {
        "gen_ai.operation.name" => "generation",
        "gen_ai.request.model" => model,
        "gen_ai.provider.name" => provider_name,
        "server.address" => provider_host,
        "server.port" => provider_port
      }.compact
      span_name = ["generation", model].compact.join(" ")
      @current_generation = @tracer.start_span(span_name.empty? ? "gen_ai.generation" : span_name, kind: :client, attributes:)
      @current_generation.add_event("gen_ai.generation.start")
      @current_generation
    end

    ##
    # @param (see LLM::Tracer#on_generation_finish)
    def on_generation_finish(generation_span: nil, res: nil, model: nil)
      span = generation_span || @current_generation
      return nil unless span
      
      attributes = {
        "gen_ai.operation.name" => "generation",
        "gen_ai.request.model" => model,
        "gen_ai.response.model" => model
      }.compact
      
      # Add response-specific attributes if available
      if res
        attributes.merge!({
          "gen_ai.response.id" => res.id,
          "gen_ai.usage.input_tokens" => res.usage&.input_tokens,
          "gen_ai.usage.output_tokens" => res.usage&.output_tokens
        }.compact)
      end
      
      attributes.each { span.set_attribute(_1, _2) }
      span.add_event("gen_ai.generation.finish")
      span.tap(&:finish)
      @current_generation = nil
    end

    ##
    # @param (see LLM::Tracer#on_generation_error)
    def on_generation_error(generation_span: nil, ex: nil)
      span = generation_span || @current_generation
      return nil unless span
      
      attributes = {"error.type" => ex.class.to_s}.compact
      attributes.each { span.set_attribute(_1, _2) }
      span.add_event("gen_ai.generation.finish")
      span.status = ::OpenTelemetry::Trace::Status.error(ex.message)
      span.tap(&:finish)
      @current_generation = nil
    end

    ##
    # @param (see LLM::Tracer#on_request_start)
    def on_request_start(operation:, model: nil, parent_span: nil)
      parent = parent_span || @current_generation
      case operation
      when "chat" then start_chat(operation:, model:, parent_span: parent)
      when "retrieval" then start_retrieval(operation:, parent_span: parent)
      else nil
      end
    end

    ##
    # @param (see LLM::Tracer#on_request_finish)
    def on_request_finish(operation:, res:, model: nil, span: nil)
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
    def on_tool_start(id:, name:, arguments:, model:, parent_span: nil)
      parent = parent_span || @current_generation
      attributes = {
        "gen_ai.operation.name" => "execute_tool",
        "gen_ai.request.model" => model,
        "gen_ai.tool.call.id" => id,
        "gen_ai.tool.name" => name,
        "gen_ai.tool.call.arguments" => LLM.json.dump(arguments),
        "gen_ai.provider.name" => provider_name,
        "server.address" => provider_host,
        "server.port" => provider_port
      }.compact
      span_name = ["execute_tool", name].compact.join(" ")
      span_options = { kind: :client, attributes: }
      span_options[:parent] = parent if parent
      span = @tracer.start_span(span_name.empty? ? "gen_ai.tool" : span_name, **span_options)
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
    # @note
    # This method returns an empty array for exporters that
    # do not implement 'finished_spans' such as the OTLP
    # exporter
    # @return [Array<OpenTelemetry::SDK::Trace::SpanData>]
    def spans
      return [] unless @exporter.respond_to?(:finished_spans)
      flush!
      @exporter.finished_spans
    end

    ##
    # Returns the current active generation span
    # @return [Object, nil]
    def current_generation
      @current_generation
    end

    ##
    # Flushes queued telemetry to the configured exporter.
    # @note
    #  Exports are batched in the background by default.
    #  Long-lived processes usually do not need to call this method.
    #  Short-lived scripts should call {#flush!} before exit to reduce
    #  the risk of losing spans that are still buffered.
    # @return (see LLM::Tracer#flush!)
    def flush!
      @tracer_provider.force_flush
      nil
    end

    private

    ##
    # @api private
    def setup!
      require "opentelemetry/sdk" unless defined?(OpenTelemetry)
      @exporter ||= OpenTelemetry::SDK::Trace::Export::InMemorySpanExporter.new
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

    def start_chat(operation:, model:, parent_span: nil)
      attributes = {
        "gen_ai.operation.name" => operation,
        "gen_ai.request.model" => model,
        "gen_ai.provider.name" => provider_name,
        "server.address" => provider_host,
        "server.port" => provider_port
      }.compact
      span_name = [operation, model].compact.join(" ")
      span_options = { kind: :client, attributes: }
      span_options[:parent] = parent_span if parent_span
      span = @tracer.start_span(span_name.empty? ? "gen_ai.request" : span_name, **span_options)
      span.add_event("gen_ai.request.start")
      span
    end

    def start_retrieval(operation:, parent_span: nil)
      attributes = {
        "gen_ai.operation.name" => operation,
        "gen_ai.provider.name" => provider_name,
        "server.address" => provider_host,
        "server.port" => provider_port
      }.compact
      span_options = { kind: :client, attributes: }
      span_options[:parent] = parent_span if parent_span
      span = @tracer.start_span(operation, **span_options)
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
