# frozen_string_literal: true

require_relative "setup"

RSpec.describe LLM::Agent do
  let(:provider) { LLM.openai(key: "test") }
  let(:empty_functions) { [].extend(LLM::Function::Array) }

  shared_examples "agent behavior" do
    let(:schema) do
      Class.new(LLM::Schema) do
        property :answer, String, "Answer", required: true
      end
    end

    let(:tool) do
      Class.new(LLM::Tool) do
        name "echo"
        description "Echo a value"
        param :value, String, "Value", required: true
        def call(value:) = {value:}
      end
    end

    let(:agent_class) do
      tool_class = tool
      schema_class = schema
      Class.new(described_class) do
        model "gpt-4.1"
        instructions "You are helpful"
        tools tool_class
        schema schema_class
      end
    end

    describe ".new" do
      it "passes DSL defaults to the context" do
        expect(LLM::Context).to receive(:new).with(
          provider,
          {model: "gpt-4.1", tools: [tool], schema:}
        ).and_call_original
        agent_class.new(provider)
      end

      it "keeps concurrency on the agent" do
        klass = Class.new(described_class) do
          model "gpt-4.1"
          concurrency :thread
        end
        expect(LLM::Context).to receive(:new).with(
          provider,
          {model: "gpt-4.1", tools: []}
        ).and_call_original
        expect(klass.new(provider).concurrency).to eq(:thread)
      end

      it "passes DSL skills to the context" do
        skill_path = "/tmp/weather"
        skill = double("skill", to_tool: tool)
        klass = Class.new(described_class) do
          model "gpt-4.1"
          skills skill_path
        end
        expect(LLM::Skill).to receive(:load).with(skill_path).and_return(skill)
        expect(LLM::Context).to receive(:new).with(
          provider,
          {model: "gpt-4.1", tools: [], skills: [skill_path]}
        ).and_call_original
        klass.new(provider)
      end
    end

    describe "#talk" do
      let(:agent) { agent_class.new(provider) }
      let(:prompt) do
        LLM::Prompt.new(provider) do
          system "You are helpful"
          user "hello"
        end
      end

      it "sends the prompt through the provider" do
        expect(agent.llm).to receive(:complete)
          .with(prompt, instance_of(Hash))
          .and_return(double(choices: [LLM::Message.new("assistant", "hello")]))
        agent.talk(prompt)
      end
    end
  end

  describe "context parity" do
    let(:returns) { [double("return")] }
    let(:usage) { LLM::Object.from(input_tokens: 1, output_tokens: 2, total_tokens: 3) }
    let(:messages) { double("messages") }
    let(:functions) { empty_functions }
    let(:cost) { double("cost") }
    let(:payload) { {"schema_version" => 1, "model" => "gpt-4.1", "messages" => []} }
    let(:ctx) do
      instance_double(
        LLM::Context,
        messages:,
        functions:,
        returns:,
        usage:,
        mode: :completions,
        cost:,
        context_window: 128_000,
        model: "gpt-4.1",
        to_h: payload,
        prompt: :prompt,
        image_url: :image,
        local_file: :local_file,
        remote_file: :remote_file,
        tracer: :tracer
      )
    end
    let(:agent) { described_class.new(provider) }

    before do
      allow(LLM::Context).to receive(:new).and_return(ctx)
      allow(ctx).to receive(:interrupt!)
      allow(ctx).to receive(:call).with(:functions).and_return(returns)
      allow(ctx).to receive(:wait).with(:thread).and_return(returns)
    end

    describe "#messages" do
      subject { agent.messages }
      it { is_expected.to be(messages) }
    end

    describe "#functions" do
      subject { agent.functions }
      it { is_expected.to be(functions) }
    end

    describe "#returns" do
      subject { agent.returns }
      it { is_expected.to be(returns) }
    end

    describe "#usage" do
      subject { agent.usage }
      it { is_expected.to be(usage) }
    end

    describe "#mode" do
      subject { agent.mode }
      it { is_expected.to eq(:completions) }
    end

    describe "#cost" do
      subject { agent.cost }
      it { is_expected.to be(cost) }
    end

    describe "#context_window" do
      subject { agent.context_window }
      it { is_expected.to eq(128_000) }
    end

    describe "#model" do
      subject { agent.model }
      it { is_expected.to eq("gpt-4.1") }
    end

    describe "#to_h" do
      subject { agent.to_h }
      it { is_expected.to eq(payload) }
    end

    describe "#to_json" do
      subject { agent.to_json }
      it { is_expected.to eq(payload.to_json) }
    end

    describe "#prompt" do
      it "forwards to the context" do
        expect(agent.prompt {}).to eq(:prompt)
      end
    end

    describe "#image_url" do
      it "forwards to the context" do
        expect(agent.image_url("https://example.com")).to eq(:image)
      end
    end

    describe "#local_file" do
      it "forwards to the context" do
        expect(agent.local_file("/tmp/x")).to eq(:local_file)
      end
    end

    describe "#remote_file" do
      it "forwards to the context" do
        expect(agent.remote_file(:response)).to eq(:remote_file)
      end
    end

    describe "#tracer" do
      subject { agent.tracer }
      it { is_expected.to eq(:tracer) }
    end

    describe "#interrupt!" do
      it "forwards to the context" do
        agent.interrupt!
        expect(ctx).to have_received(:interrupt!)
      end
    end

    describe "#cancel!" do
      it "aliases #interrupt!" do
        agent.cancel!
        expect(ctx).to have_received(:interrupt!)
      end
    end

    describe "#call" do
      it "forwards to the context" do
        expect(agent.call(:functions)).to eq(returns)
      end
    end

    describe "#wait" do
      it "forwards to the context" do
        expect(agent.wait(:thread)).to eq(returns)
      end
    end
  end

  describe "tool loop concurrency" do
    let(:tool_return) { double("return") }
    let(:pending_functions) { [double("function")].extend(LLM::Function::Array) }
    let(:ctx) do
      instance_double(
        LLM::Context,
        messages: [],
        functions: pending_functions,
        returns: [],
        usage: LLM::Object.from(input_tokens: 0, output_tokens: 0, total_tokens: 0),
        mode: :completions,
        cost: double("cost"),
        context_window: 0,
        model: "gpt-4.1",
        to_h: {"schema_version" => 1, "model" => "gpt-4.1", "messages" => []},
        prompt: nil,
        image_url: nil,
        local_file: nil,
        remote_file: nil,
        tracer: nil
      )
    end

    before do
      allow(LLM::Context).to receive(:new).and_return(ctx)
      allow(ctx).to receive(:talk).and_return(double("first_response"), double("second_response"))
      allow(ctx).to receive(:respond).and_return(double("first_response"), double("second_response"))
      allow(ctx).to receive(:call)
      allow(ctx).to receive(:wait)
      allow(ctx).to receive(:functions).and_return(pending_functions, empty_functions)
    end

    describe "#talk" do
      it "uses sequential calls by default" do
        agent = described_class.new(provider)
        allow(ctx).to receive(:call).with(:functions).and_return([tool_return])
        agent.talk("hello")
        expect(ctx).to have_received(:call).with(:functions)
        expect(ctx).not_to have_received(:wait)
        expect(ctx).to have_received(:talk).with("hello", {})
        expect(ctx).to have_received(:talk).with([tool_return], {})
      end
    end

    describe "#respond" do
      let(:agent_class) do
        strategy = concurrency
        Class.new(described_class) do
          concurrency(strategy)
        end
      end
      let(:agent) { agent_class.new(provider) }

      context "when concurrency is a single mode" do
        let(:concurrency) { :thread }

        it "uses the configured concurrency for tool loops" do
          allow(ctx).to receive(:wait).with(:thread).and_return([tool_return])
          agent.respond("hello")
          expect(ctx).to have_received(:wait).with(:thread)
          expect(ctx).not_to have_received(:call)
          expect(ctx).to have_received(:respond).with("hello", {})
          expect(ctx).to have_received(:respond).with([tool_return], {})
        end
      end

      context "when concurrency is a list of queued task types" do
        let(:concurrency) { [:thread, :ractor] }

        it "waits for the configured task types" do
          allow(ctx).to receive(:wait).with([:thread, :ractor]).and_return([tool_return])
          agent.respond("hello")
          expect(ctx).to have_received(:wait).with([:thread, :ractor])
          expect(ctx).not_to have_received(:call)
          expect(ctx).to have_received(:respond).with("hello", {})
          expect(ctx).to have_received(:respond).with([tool_return], {})
        end
      end
    end
  end

  context "when given openai" do
    let(:provider) { LLM.openai(key: "test") }
    include_examples "agent behavior"
  end

  context "when given google" do
    let(:provider) { LLM.google(key: "test") }
    include_examples "agent behavior"
  end

  context "when given anthropic" do
    let(:provider) { LLM.anthropic(key: "test") }
    include_examples "agent behavior"
  end

  context "when given xai" do
    let(:provider) { LLM.xai(key: "test") }
    include_examples "agent behavior"
  end

  context "when given zai" do
    let(:provider) { LLM.zai(key: "test") }
    include_examples "agent behavior"
  end

  context "when given deepseek" do
    let(:provider) { LLM.deepseek(key: "test") }
    include_examples "agent behavior"
  end
end
