# frozen_string_literal: true

require "setup"

RSpec.describe LLM::Provider do
  context "with openai" do
    let(:provider) { LLM.openai(key: ENV["OPENAI_SECRET"]) }

    context "when given the with method" do
      subject { provider.send(:headers) }

      before do
        provider
          .with(headers: {"OpenAI-Organization" => "llmrb"})
          .with(headers: {"OpenAI-Project" => "llmrb/llm"})
      end

      it "adds headers" do
        is_expected.to include(
          "OpenAI-Organization" => "llmrb",
          "OpenAI-Project" => "llmrb/llm"
        )
      end
    end
  end

  context "with bedrock" do
    subject(:provider) do
      LLM.bedrock(
        access_key_id: "AKIA_TEST",
        secret_access_key: "SECRET",
        region: "us-east-1"
      )
    end

    it "builds a Bedrock provider" do
      expect(provider).to be_a(LLM::Bedrock)
      expect(provider.name).to eq(:bedrock)
    end
  end

  context "#interrupt!" do
    let(:provider) { LLM.openai(key: "test") }
    let(:owner) { Fiber.current }

    it "finishes an active transient request" do
      http = Net::HTTP.new("example.com")
      allow(http).to receive(:active?).and_return(true)
      allow(http).to receive(:finish)
      req = LLM::Provider::Transport::HTTP::Interruptible::Request.new(http:)
      provider.send(:transport).send(:set_request, req, owner)
      provider.interrupt!(owner)
      expect(http).to have_received(:finish)
    end

    it "finishes an active persistent connection" do
      persistent_class = if defined?(Net::HTTP::Persistent)
        Net::HTTP::Persistent
      else
        stub_const("Net::HTTP::Persistent", Class.new)
      end
      client = persistent_class.allocate
      connection = double(:connection, http: nil)
      allow(client).to receive(:finish)
      req = LLM::Provider::Transport::HTTP::Interruptible::Request.new(http: client, connection:)
      provider.send(:transport).send(:set_request, req, owner)
      provider.interrupt!(owner)
      expect(client).to have_received(:finish).with(connection)
    end
  end
end
