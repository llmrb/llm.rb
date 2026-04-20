# frozen_string_literal: true

require "setup"
require "fileutils"
require "tempfile"
require "tmpdir"

RSpec.describe LLM::Context do
  let(:ctx) { LLM::Context.new(provider, model:) }

  context "when given openai" do
    let(:provider) { LLM.openai(key: "test") }
    let(:model) { "gpt-5.4" }

    context "#context_window" do
      subject { ctx.context_window }
      it { is_expected.to eq(1050000) }
    end
  end

  context "when given anthropic" do
    let(:provider) { LLM.anthropic(key: "test") }
    let(:model) { "claude-sonnet-4-20250514" }

    context "#context_window" do
      subject { ctx.context_window }
      it { is_expected.to eq(200000) }
    end
  end

  context "when given google" do
    let(:provider) { LLM.google(key: "test") }
    let(:model) { "gemini-2.5-flash" }

    context "#context_window" do
      subject { ctx.context_window }
      it { is_expected.to eq(1048576) }
    end
  end

  context "when given deepseek" do
    let(:provider) { LLM.deepseek(key: "test") }
    let(:model) { "deepseek-chat" }

    context "#context_window" do
      subject { ctx.context_window }
      it { is_expected.to eq(131072) }
    end
  end

  context "when given a model that does not exist" do
    let(:provider) { LLM.deepseek(key: "test") }
    let(:model) { "does-not-exist" }

    context "#context_window" do
      subject { ctx.context_window }
      it { is_expected.to be_zero }
    end
  end

  context "when configured with responses mode" do
    let(:provider) { LLM.openai(key: "test") }
    let(:model) { "gpt-5.4" }
    let(:ctx) { LLM::Context.new(provider, model:, mode: :responses) }
    let(:responses) { double }
    let(:response) { double(choices: [LLM::Message.new("assistant", "Paris")]) }

    it "routes talk through the responses API" do
      allow(provider).to receive(:responses).and_return(responses)
      expect(responses).to receive(:create).with("What is the capital of France?", hash_including(model:))
        .and_return(response)
      expect(ctx.talk("What is the capital of France?")).to eq(response)
    end
  end

  context "when configured with skills" do
    let(:provider) { LLM.openai(key: "test") }
    let(:model) { "gpt-5.4" }
    let(:skill_path) { "/tmp/weather" }
    let(:tool) { double("tool") }
    let(:skill) { double("skill", to_tool: tool) }

    it "loads skills into tools" do
      expect(LLM::Skill).to receive(:load).with(skill_path).and_return(skill)
      ctx = described_class.new(provider, model:, skills: [skill_path])
      expect(ctx.instance_variable_get(:@params)[:tools]).to eq([tool])
    end
  end

  context "when serializing tagged prompt objects" do
    let(:provider) { LLM.openai(key: "test") }
    let(:model) { "gpt-5.4" }
    let(:image_url) { "https://example.com/cat.png" }
    let(:remote_file) do
      LLM::Object.from(
        "file?" => true,
        "id" => "file_123",
        "filename" => "photo.png",
        "mime_type" => "image/png",
        "uri" => "https://example.com/photo.png",
        "file_type" => "image"
      )
    end
    let(:tempfile) do
      Tempfile.new(["llmrb", ".txt"]).tap do |file|
        file.write("hello")
        file.flush
      end
    end
    let(:tmpdir) { Dir.mktmpdir("llmrb-context") }
    let(:serialized) { File.join(tmpdir, "context.json") }
    let(:message) do
      LLM::Message.new("user", [
        ctx.image_url(image_url),
        ctx.local_file(tempfile.path),
        ctx.remote_file(remote_file)
      ])
    end
    let(:restored) do
      described_class.new(provider, model:).tap do |other|
        ctx.messages << message
        other.restore(string: ctx.to_json)
      end
    end
    let(:content) { restored.messages.first.content }

    after do
      tempfile.close!
      FileUtils.remove_entry(tmpdir)
    end

    context "#restore" do
      it "restores image_url content" do
        expect(content.fetch(0).kind).to eq(:image_url)
        expect(content.fetch(0).value).to eq(image_url)
      end

      it "restores local_file content" do
        expect(content.fetch(1).kind).to eq(:local_file)
        expect(content.fetch(1).value).to be_a(LLM::File)
        expect(content.fetch(1).value.path).to eq(tempfile.path)
      end

      it "restores remote_file content" do
        expect(content.fetch(2).kind).to eq(:remote_file)
        expect(content.fetch(2).value.file?).to eq(true)
        expect(content.fetch(2).value.id).to eq("file_123")
        expect(content.fetch(2).value.filename).to eq("photo.png")
        expect(content.fetch(2).value.mime_type).to eq("image/png")
        expect(content.fetch(2).value.uri).to eq("https://example.com/photo.png")
        expect(content.fetch(2).value.file_type).to eq("image")
      end
    end

    context "#serialize" do
      let(:restored) do
        described_class.new(provider, model:).tap do |other|
          ctx.messages << message
          ctx.serialize(path: serialized)
          other.restore(path: serialized)
        end
      end

      it "round-trips tagged prompt objects through a file" do
        expect(restored.messages.size).to eq(1)
        expect(restored.messages.first).to be_a(LLM::Message)
        expect(content.fetch(0).kind).to eq(:image_url)
        expect(content.fetch(0).value).to eq(image_url)
        expect(content.fetch(1).kind).to eq(:local_file)
        expect(content.fetch(1).value).to be_a(LLM::File)
        expect(content.fetch(1).value.path).to eq(tempfile.path)
        expect(content.fetch(2).kind).to eq(:remote_file)
        expect(content.fetch(2).value.file?).to eq(true)
        expect(content.fetch(2).value.id).to eq("file_123")
      end
    end
  end

  context "when a tool call already has a matching tool return" do
    let(:provider) { LLM.openai(key: "test") }
    let(:model) { "gpt-5.4" }
    let(:tool) do
      Class.new(LLM::Tool) do
        name "system"
        description "run shell commands"
      end
    end

    before do
      ctx.messages << LLM::Message.new("assistant", nil, {
        tools: [tool],
        tool_calls: [
          {id: "call_1", type: "function", function: {name: "system", arguments: {command: "date"}}}
        ]
      })
      ctx.messages << LLM::Message.new("tool", LLM::Function::Return.new("call_1", "system", {success: true}))
    end

    it "returns tool returns from ctx.returns" do
      expect(ctx.returns.map(&:id)).to eq(["call_1"])
    end

    it "does not include the tool call in ctx.functions" do
      expect(ctx.functions).to be_empty
    end
  end

  context "#call" do
    let(:provider) { LLM.openai(key: "test") }
    let(:model) { "gpt-5.4" }

    it "requires an explicit target" do
      expect { ctx.call }.to raise_error(ArgumentError)
    end

    it "forwards :functions to ctx.functions.call" do
      pending = [].extend(LLM::Function::Array)
      expect(ctx).to receive(:functions).and_return(pending)
      expect(pending).to receive(:call).and_return([])
      expect(ctx.call(:functions)).to eq([])
    end

    it "raises for an unknown target" do
      expect { ctx.call(:unknown) }.to raise_error(
        ArgumentError,
        /Unknown target: :unknown\. Expected :functions/
      )
    end
  end

  context "when configured with a stream that supports wait" do
    let(:provider) { LLM.openai(key: "test") }
    let(:model) { "gpt-5.4" }
    let(:stream) { LLM::Stream.new }
    let(:ctx) { LLM::Context.new(provider, model:, stream:) }
    let(:tool) do
      Class.new(LLM::Tool) do
        name "system"

        def call(command:)
          {"ok" => command == "date"}
        end
      end
    end

    it "forwards #wait to the configured stream when the queue has work" do
      stream.queue << LLM::Function::Return.new("call_1", "system", {"ok" => true})
      expect(stream).to receive(:wait).with(:thread).and_return([])
      expect(ctx.wait(:thread)).to eq([])
    end

    it "falls back to pending functions when the queue is empty" do
      pending = [].extend(LLM::Function::Array)
      expect(ctx).to receive(:functions).and_return(pending)
      expect(pending).to receive(:wait).with(:thread).and_return([])
      expect(ctx.wait(:thread)).to eq([])
    end
  end

  context "#interrupt!" do
    let(:provider) { LLM.openai(key: "test") }
    let(:model) { "gpt-5.4" }

    it "forwards to the provider" do
      owner = Fiber.new {}
      ctx.instance_variable_set(:@owner, owner)
      expect(provider).to receive(:interrupt!).with(owner).and_return(nil)
      expect(ctx.interrupt!).to be_nil
    end

    it "tracks the executing fiber as the interrupt owner" do
      owner = Fiber.new do
        allow(provider).to receive(:complete).and_return(
          double(choices: [LLM::Message.new("assistant", "hello")])
        )
        ctx.talk("hello")
        expect(provider).to receive(:interrupt!).with(Fiber.current).and_return(nil)
        expect(ctx.interrupt!).to be_nil
      end
      owner.resume
    end
  end
end
