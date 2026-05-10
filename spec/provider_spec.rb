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

  context "with a transport class" do
    it "builds a transport from the provider settings" do
      provider = LLM.openai(key: "test", transport: LLM::Transport.net_http_persistent)
      expect(provider.send(:transport)).to be_a(LLM::Transport::PersistentHTTP)
    end
  end

  context "#interrupt!" do
    let(:provider) { LLM.openai(key: "test") }
    let(:owner) { Fiber.current }

    it "finishes an active transient request" do
      http = Net::HTTP.new("example.com")
      allow(http).to receive(:active?).and_return(true)
      allow(http).to receive(:finish)
      req = LLM::Transport::HTTP::Request.new(client: http)
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
      transport = LLM::Transport::PersistentHTTP.new(host: "api.openai.com", port: 443, timeout: 60, ssl: true)
      provider = LLM.openai(key: "test", transport:)
      client = persistent_class.allocate
      connection = double(:connection, http: nil)
      allow(client).to receive(:finish)
      req = LLM::Transport::PersistentHTTP::Request.new(client:, connection:)
      provider.send(:transport).send(:set_request, req, owner)
      provider.interrupt!(owner)
      expect(client).to have_received(:finish).with(connection)
    end
  end
end
