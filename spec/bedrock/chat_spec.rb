# frozen_string_literal: true

require "setup"

RSpec.describe "LLM::Context: bedrock" do
  let(:provider) do
    LLM.bedrock(
      access_key_id: ENV["AWS_ACCESS_KEY_ID"] || "TOKEN",
      secret_access_key: ENV["AWS_SECRET_ACCESS_KEY"] || "TOKEN",
      region: ENV["AWS_REGION"] || "us-east-1",
      session_token: ENV["AWS_SESSION_TOKEN"]
    )
  end
  let(:llm) { provider }
  let(:ctx) { LLM::Context.new(provider, params) }
  let(:params) { {model: "amazon.nova-lite-v1:0"} }
  before { allow(provider).to receive(:default_model).and_return("amazon.nova-lite-v1:0") }

  context LLM::Context do
    include_examples "LLM::Context: completions", :bedrock
    include_examples "LLM::Context: text stream", :bedrock
    include_examples "LLM::Context: tool stream", :bedrock

    context "when given a completion contract for bedrock",
            vcr: {cassette_name: "bedrock/chat/completion_contract"} do
      let(:ctx) { LLM::Context.new(provider, model: "amazon.nova-lite-v1:0") }

      subject(:completion) { ctx.talk("Hello, world!") }

      it "implements the completion interface" do
        LLM::Contract::Completion.instance_methods(false).each do |m|
          expect(completion).to respond_to(m)
        end
      end

      it "returns choices as LLM::Message" do
        expect(completion.choices).to all(be_a(LLM::Message))
      end
    end
  end

  context LLM::Function do
    include_examples "LLM::Context: functions", :bedrock
  end

  context LLM::Schema do
    let(:params) { {model: "deepseek.v3.2"} }
    before { allow(provider).to receive(:default_model).and_return("deepseek.v3.2") }
    include_examples "LLM::Context: schema", :bedrock
  end
end
