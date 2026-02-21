# frozen_string_literal: true

require "setup"

RSpec.describe LLM::Tracer do
  let(:provider) { LLM::OpenAI.new }
  let(:tracer) { described_class.new(provider) }
  let(:openai) do
    Class.new do
      def initialize
        @host = "api.openai.com"
        @port = 443
      end
    end
  end

  before { stub_const("LLM::OpenAI", openai) }

  describe "#spans" do
    it "returns an empty array" do
      expect(tracer.spans).to eq([])
    end
  end

  describe "#flush!" do
    it "returns nil" do
      expect(tracer.flush!).to be_nil
    end
  end
end

RSpec.describe LLM::Tracer::Telemetry do
  let(:provider) { LLM::OpenAI.new }
  let(:tracer) { described_class.new(provider) }
  let(:openai) do
    Class.new do
      def initialize
        @host = "api.openai.com"
        @port = 443
      end
    end
  end

  before { stub_const("LLM::OpenAI", openai) }

  describe "#on_request_start" do
    context "when given a chat operation" do
      subject { tracer.on_request_start(operation: "chat", model: "test-model") }
      it { is_expected.to be_instance_of(OpenTelemetry::SDK::Trace::Span) }
    end

    context "when given a retrieval operation" do
      subject { tracer.on_request_start(operation: "retrieval") }
      it { is_expected.to be_instance_of(OpenTelemetry::SDK::Trace::Span) }
    end
  end

  describe "#on_request_finish" do
    context "when given a chat operation" do
      let(:usage) { LLM::Usage.new(input_tokens: 1, output_tokens: 2) }
      let(:res) { double("LLM::Response", id: "res_123", usage:, service_tier: "default", system_fingerprint: "yabadabadoo") }
      let(:span) { tracer.on_request_start(operation: "chat", model: "test-model") }
      let(:attributes) { {"gen_ai.operation.name" => "chat", "gen_ai.request.model" => "test-model"} }

      before { tracer.on_request_finish(operation: "chat", model: "test-model", res:, span:) }

      it "finishes the span" do
        expect(span.name).to eq("chat test-model")
        expect(span.attributes).to match(hash_including(attributes))
      end
    end

    context "when given a retrieval operation" do
      let(:res) { double("LLM::Response", size: 1, has_more: false) }
      let(:span) { tracer.on_request_start(operation: "retrieval") }
      let(:attributes) { {"gen_ai.operation.name" => "retrieval"} }

      before { tracer.on_request_finish(operation: "retrieval", res:, span:) }

      it "finishes the span" do
        expect(span.name).to eq("retrieval")
        expect(span.attributes).to match(hash_including(attributes))
      end
    end
  end

  describe "#spans" do
    let(:tracer) { described_class.new(provider, exporter:) }
    let(:exporter) do
      Class.new do
        def export(*) = OpenTelemetry::SDK::Trace::Export::SUCCESS
        def shutdown(*) = OpenTelemetry::SDK::Trace::Export::SUCCESS
        def force_flush(*) = OpenTelemetry::SDK::Trace::Export::SUCCESS
      end.new
    end

    it "returns an empty array" do
      expect(tracer.spans).to eq([])
    end
  end

  describe "#flush!" do
    it "returns nil" do
      expect(tracer.flush!).to be_nil
    end
  end
end
