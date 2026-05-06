# frozen_string_literal: true

require "setup"

RSpec.describe "LLM::Bedrock::ResponseAdapter::Completion" do
  let(:body) do
    LLM::Object.from(
      output: {message: {role: "assistant", content:}},
      usage:,
      modelId: "test-model"
    )
  end
  let(:http_response) { Struct.new(:body).new(body) }
  let(:response) { LLM::Response.new(http_response) }
  let(:completion) { LLM::Bedrock::ResponseAdapter.adapt(response, type: :completion) }

  context "when usage is nil" do
    let(:content) { [] }
    let(:usage) { nil }

    it "returns 0 for total tokens" do
      expect(completion.total_tokens).to eq(0)
    end
  end

  context "when reasoning content is present" do
    let(:usage) { LLM::Object.from(inputTokens: 10, outputTokens: 20) }
    let(:content) do
      [
        {"reasoningContent" => {"text" => "Think"}},
        {"text" => "Answer"}
      ]
    end

    it "preserves reasoning content on the message" do
      expect(completion.messages.first.reasoning_content).to eq("Think")
    end

    it "returns the assistant content" do
      expect(completion.content).to eq("Answer")
    end
  end
end
