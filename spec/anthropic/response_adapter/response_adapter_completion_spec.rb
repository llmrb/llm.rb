# frozen_string_literal: true

require "setup"

RSpec.describe "LLM::Anthropic::ResponseAdapter::Completion" do
  let(:body) { LLM::Object.from(content: [], usage:, model: "test-model") }
  let(:http_response) { Struct.new(:body).new(body) }
  let(:response) { LLM::Response.new(http_response) }
  let(:completion) { LLM::Anthropic::ResponseAdapter.adapt(response, type: :completion) }

  context "when usage is nil" do
    let(:usage) { nil }

    it "returns 0 for input tokens" do
      expect(completion.input_tokens).to eq(0)
    end

    it "returns 0 for output tokens" do
      expect(completion.output_tokens).to eq(0)
    end

    it "returns 0 for total tokens" do
      expect(completion.total_tokens).to eq(0)
    end
  end

  context "when usage is provided" do
    let(:usage) do
      LLM::Object.from(
        input_tokens: 10,
        output_tokens: 20,
        cache_read_input_tokens: 30,
        cache_creation_input_tokens: 40
      )
    end

    it "returns correct input tokens" do
      expect(completion.input_tokens).to eq(10)
    end

    it "returns correct output tokens" do
      expect(completion.output_tokens).to eq(20)
    end

    it "returns correct total tokens" do
      expect(completion.total_tokens).to eq(30)
    end

    it "returns correct cache read tokens" do
      expect(completion.cache_read_tokens).to eq(30)
    end

    it "returns correct cache write tokens" do
      expect(completion.cache_write_tokens).to eq(40)
    end
  end
end
