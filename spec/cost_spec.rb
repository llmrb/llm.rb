# frozen_string_literal: true

require "setup"

RSpec.describe LLM::Cost do
  describe ".from" do
    let(:provider) { LLM.openai(key: "test") }
    let(:model) { "gpt-5.4" }
    let(:ctx) { LLM::Context.new(provider, model:) }
    let(:usage) do
      LLM::Usage.new(
        input_tokens: 1000,
        output_tokens: 2000,
        input_audio_tokens: 300,
        output_audio_tokens: 400,
        cache_read_tokens: 3000,
        cache_write_tokens: 500,
        reasoning_tokens: 4000,
        total_tokens: 10_000
      )
    end

    before do
      allow(ctx).to receive(:usage).and_return(usage)
    end

    context "when pricing is present" do
      let(:pricing) do
        LLM::Object.from(
          input: 1.5,
          output: 6.0,
          input_audio: 3.0,
          output_audio: 12.0,
          cache_read: 0.5,
          cache_write: 1.25
        )
      end
      subject(:cost) { described_class.from(ctx) }

      before do
        expect(LLM.registry_for(provider)).to receive(:cost).with(model:).and_return(pricing)
      end

      it "builds a cost breakdown from usage" do
        expect(cost.to_h).to eq(
          input: 0.0015,
          output: 0.012,
          input_audio: 0.0009,
          output_audio: 0.0048,
          cache_read: 0.0015,
          cache_write: 0.000625,
          reasoning: 0.024,
          total: 0.045325
        )
      end
    end

    context "when the model cannot be priced" do
      before do
        expect(LLM.registry_for(provider)).to receive(:cost).with(model:)
          .and_raise(LLM::NoSuchModelError)
      end
      subject(:cost) { described_class.from(ctx) }

      it { expect(cost).to eq(described_class.new) }
    end

    context "when usage is zero or pricing is unavailable" do
      let(:usage) do
        LLM::Usage.new(
          input_tokens: 1000,
          output_tokens: 2000,
          input_audio_tokens: 0,
          output_audio_tokens: nil,
          cache_read_tokens: 0,
          cache_write_tokens: nil,
          reasoning_tokens: nil,
          total_tokens: 3000
        )
      end
      let(:pricing) do
        LLM::Object.from(
          input: 1.5,
          output: 6.0,
          input_audio: nil,
          output_audio: nil,
          cache_read: nil,
          cache_write: nil
        )
      end
      subject(:cost) { described_class.from(ctx) }

      before do
        expect(LLM.registry_for(provider)).to receive(:cost).with(model:).and_return(pricing)
      end

      it "omits nil cost components" do
        expect(cost.to_h).to eq(
          input: 0.0015,
          output: 0.012,
          total: 0.0135
        )
      end
    end
  end
end
