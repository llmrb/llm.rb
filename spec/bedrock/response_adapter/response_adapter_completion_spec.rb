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
  let(:request_id) { nil }
  let(:http_response) do
    Class.new do
      attr_reader :body

      def initialize(body, request_id)
        @body = body
        @request_id = request_id
      end

      def [](key)
        return @request_id if key == "x-amzn-requestid"
      end
    end.new(body, request_id)
  end
  let(:response) { LLM::Response.new(http_response) }
  let(:completion) { LLM::Bedrock::ResponseAdapter.adapt(response, type: :completion) }

  context "when the response includes a request id" do
    let(:content) { [] }
    let(:usage) { nil }
    let(:request_id) { "bedrock-request-123" }

    it "returns the response id" do
      expect(completion.id).to eq("bedrock-request-123")
    end
  end

  context "when the response does not include a request id" do
    let(:content) { [] }
    let(:usage) { nil }

    it "returns nil" do
      expect(completion.id).to be_nil
    end
  end

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
