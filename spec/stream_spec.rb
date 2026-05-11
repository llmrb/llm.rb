# frozen_string_literal: true

require "setup"

RSpec.describe LLM::Stream do
  let(:stream) { described_class.new }
  let(:ctx) { LLM::Context.new(LLM.openai(key: "test"), model: "gpt-5.4") }
  let(:compactor) { LLM::Compactor.new(ctx) }
  let(:transformer) { Object.new }

  let(:tool_class) do
    Class.new(LLM::Tool) do
      name "system"

      def call(command:)
        {"ok" => command == "date"}
      end
    end
  end

  let(:tool) do
    tool_class.function.dup.tap do |fn|
      fn.id = "call_1"
      fn.arguments = {"command" => "date"}
    end
  end

  describe "#on_content" do
    it "returns nil" do
      expect(stream.on_content("hello")).to be_nil
    end
  end

  describe "#<<" do
    it "aliases #on_content" do
      expect(stream << "hello").to be_nil
    end
  end

  describe "#on_reasoning_content" do
    it "returns nil" do
      expect(stream.on_reasoning_content("think")).to be_nil
    end
  end

  describe "#on_tool_call" do
    it "returns nil" do
      expect(stream.on_tool_call(tool, nil)).to be_nil
    end
  end

  describe "#on_tool_return" do
    it "returns nil" do
      expect(stream.on_tool_return(tool, stream.tool_not_found(tool))).to be_nil
    end
  end

  describe "#on_compaction" do
    it "returns nil" do
      expect(stream.on_compaction(ctx, compactor)).to be_nil
    end
  end

  describe "#on_transform" do
    it "returns nil" do
      expect(stream.on_transform(ctx, transformer)).to be_nil
    end
  end

  describe "#on_transform_finish" do
    it "returns nil" do
      expect(stream.on_transform_finish(ctx, transformer)).to be_nil
    end
  end

  describe "#on_compaction_finish" do
    it "returns nil" do
      expect(stream.on_compaction_finish(ctx, compactor)).to be_nil
    end
  end

  describe "#tool_not_found" do
    it "returns an in-band error" do
      expect(stream.tool_not_found(tool).to_h).to eq(
        id: "call_1", name: "system",
        value: {error: true, type: "LLM::NoSuchToolError", message: "tool not found"}
      )
    end

    it "marks the return as an error" do
      expect(stream.tool_not_found(tool)).to be_error
    end
  end

  describe LLM::Function::Return, "#error?" do
    it "returns true for automatic error returns" do
      result = LLM::Stream.new.tool_not_found(tool)
      expect(result.error?).to be(true)
    end

    it "returns false for successful returns" do
      result = LLM::Function::Return.new("call_1", "system", {"ok" => true})
      expect(result.error?).to be(false)
    end
  end

  describe "#queue" do
    subject(:queue) { stream.queue }

    it "returns a lazy queue" do
      expect(queue).to be_a(LLM::Stream::Queue)
      expect(queue).to equal(stream.queue)
    end
  end

  describe "#wait" do
    before do
      stream.queue << stream.tool_not_found(tool)
    end

    it "forwards to the queue" do
      expect(stream.wait(:thread).map(&:to_h)).to eq(
        [{id: "call_1", name: "system", value: {error: true, type: "LLM::NoSuchToolError", message: "tool not found"}}]
      )
    end
  end

  context "when a subclass overrides callbacks" do
    let(:stream) do
      Class.new(described_class) do
        attr_reader :content, :reasoning_content, :calls, :returns, :compaction_events, :transform_events

        def initialize
          @content = +""
          @reasoning_content = +""
          @calls = []
          @returns = []
          @compaction_events = []
          @transform_events = []
        end

        def on_content(value)
          @content << value
        end

        def on_reasoning_content(value)
          @reasoning_content << value
        end

        def on_tool_call(fn, error)
          @calls << [fn, error]
        end

        def on_tool_return(fn, result)
          @returns << [fn, result]
        end

        def on_transform(ctx, transformer)
          @transform_events << [:start, ctx, transformer]
        end

        def on_transform_finish(ctx, transformer)
          @transform_events << [:finish, ctx, transformer]
        end

        def on_compaction(ctx, compactor)
          @compaction_events << [:start, ctx, compactor]
        end

        def on_compaction_finish(ctx, compactor)
          @compaction_events << [:finish, ctx, compactor]
        end
      end.new
    end

    it "handles streamed content" do
      stream.on_content("hello")
      expect(stream.content).to eq("hello")
    end

    it "handles reasoning content" do
      stream.on_reasoning_content("think")
      expect(stream.reasoning_content).to eq("think")
    end

    it "handles tool calls" do
      stream.on_tool_call(tool, nil)
      expect(stream.calls).to eq([[tool, nil]])
    end

    it "handles finished tools" do
      result = stream.tool_not_found(tool)
      stream.on_tool_return(tool, result)
      expect(stream.returns).to eq([[tool, result]])
    end

    it "handles transform start" do
      stream.on_transform(ctx, transformer)
      expect(stream.transform_events).to eq([[:start, ctx, transformer]])
    end

    it "handles transform finish" do
      stream.on_transform_finish(ctx, transformer)
      expect(stream.transform_events).to eq([[:finish, ctx, transformer]])
    end

    it "handles compaction start" do
      stream.on_compaction(ctx, compactor)
      expect(stream.compaction_events).to eq([[:start, ctx, compactor]])
    end

    it "handles compaction finish" do
      stream.on_compaction_finish(ctx, compactor)
      expect(stream.compaction_events).to eq([[:finish, ctx, compactor]])
    end
  end

  context "when using the queue" do
    describe "#wait" do
      context "when given queued function returns" do
        before do
          stream.queue << stream.tool_not_found(tool)
        end

        it "returns the queued values" do
          expect(stream.wait(:thread).map(&:to_h)).to eq(
            [{id: "call_1", name: "system", value: {error: true, type: "LLM::NoSuchToolError", message: "tool not found"}}]
          )
        end
      end

      context "when given spawned work" do
        it "waits for the spawned work" do
          stream.queue << tool.spawn(:thread)
          expect(stream.wait(:thread).map(&:to_h)).to eq(
            [{id: "call_1", name: "system", value: {"ok" => true}}]
          )
        end

        context "when tracking tool return callbacks" do
          let(:stream) do
            Class.new(described_class) do
              attr_reader :events

              def initialize
                @events = []
              end

              def on_tool_return(fn, result)
                @events << [fn, result]
              end
            end.new
          end

          it "emits on_tool_return" do
            stream.queue << tool.spawn(:thread)
            returns = stream.wait(:thread)
            expect(stream.events).to eq([[tool, returns.fetch(0)]])
          end
        end
      end

      context "when given ractor work" do
        before do
          stream.queue << tool.spawn(:ractor)
        end

        it "waits for the spawned work" do
          expect(stream.wait(:ractor).map(&:to_h)).to eq(
            [{id: "call_1", name: "system", value: {"ok" => true}}]
          )
        end
      end

      context "when given mixed spawned work" do
        subject(:returns) { stream.wait([:thread, :ractor]).map(&:to_h) }

        let(:other_tool) do
          tool_class.function.dup.tap do |fn|
            fn.id = "call_2"
            fn.arguments = {"command" => "date"}
          end
        end

        before do
          stream.queue << tool.spawn(:thread)
          stream.queue << other_tool.spawn(:ractor)
        end

        it "waits for all matching task types" do
          expect(returns).to eq(
            [
              {id: "call_1", name: "system", value: {"ok" => true}},
              {id: "call_2", name: "system", value: {"ok" => true}}
            ]
          )
        end

        context "when tracking tool return callbacks" do
          let(:stream) do
            Class.new(described_class) do
              attr_reader :events

              def initialize
                @events = []
              end

              def on_tool_return(fn, result)
                @events << [fn.id, result.id]
              end
            end.new
          end
          let(:third_tool) do
            tool_class.function.dup.tap do |fn|
              fn.id = "call_3"
              fn.arguments = {"command" => "date"}
            end
          end
          let(:expected_ids) { %w[call_1 call_2 call_3] }
          let(:result_ids) { stream.wait([:thread, :ractor]).map(&:id) }

          before do
            stream.queue << third_tool.spawn(:thread)
            result_ids
          end

          it "preserves enqueue order across mixed task groups" do
            expect(result_ids).to eq(expected_ids)
          end

          it "emits tool return callbacks in enqueue order" do
            expect(stream.events).to eq(expected_ids.map { [_1, _1] })
          end
        end
      end
    end
  end
end
