# frozen_string_literal: true

require "setup"
require "llm/providers/bedrock"

RSpec.describe LLM::Bedrock::StreamParser do
  let(:stream) do
    Class.new(LLM::Stream) do
      attr_reader :content, :reasoning_content, :calls

      def initialize
        @content = +""
        @reasoning_content = +""
        @calls = []
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

      def tool_not_found(fn)
        {id: fn.id, name: fn.name, value: {error: true}}
      end
    end.new
  end

  subject(:parser) { described_class.new(stream) }

  after { parser.free }
  before { LLM::Tool.clear_registry! }

  it "builds the streamed response in the completion response shape" do
    parser.parse!({"contentBlockIndex" => 0, "delta" => {"text" => "Hel"}}, event_type: "contentBlockDelta")
    parser.parse!({"contentBlockIndex" => 0, "delta" => {"text" => "lo"}}, event_type: "contentBlockDelta")
    parser.parse!(
      {"contentBlockIndex" => 1, "delta" => {"reasoningContent" => {"text" => "Think"}}},
      event_type: "contentBlockDelta"
    )
    parser.parse!(
      {"stopReason" => "end_turn", "metadata" => {"usage" => {"inputTokens" => 1, "outputTokens" => 2}}},
      event_type: "messageStop"
    )
    expect(parser.body.dig("output", "message", "content", 0, "text")).to eq("Hello")
    expect(parser.body.dig("output", "message", "content", 1, "reasoningContent", "text")).to eq("Think")
    expect(parser.body["usage"]).to eq({"inputTokens" => 1, "outputTokens" => 2})
    expect(stream.content).to eq("Hello")
    expect(stream.reasoning_content).to eq("Think")
  end

  it "emits tool calls after streamed tool input becomes complete" do
    stream.extra[:tracer] = Object.new
    stream.extra[:model] = "test-model"
    parser.parse!(
      {"contentBlockIndex" => 0, "start" => {"toolUse" => {"toolUseId" => "call_1", "name" => "missing"}}},
      event_type: "contentBlockStart"
    )
    parser.parse!(
      {"contentBlockIndex" => 0, "delta" => {"toolUse" => {"input" => "{\"command\""}}},
      event_type: "contentBlockDelta"
    )
    parser.parse!(
      {"contentBlockIndex" => 0, "delta" => {"toolUse" => {"input" => ":\"date\"}"}}},
      event_type: "contentBlockDelta"
    )
    parser.parse!({"contentBlockIndex" => 0}, event_type: "contentBlockStop")
    fn, error = stream.calls.fetch(0)
    expect(fn.id).to eq("call_1")
    expect(fn.name).to eq("missing")
    expect(fn.arguments).to eq({"command" => "date"})
    expect(fn.tracer).to equal(stream.extra[:tracer])
    expect(fn.model).to eq("test-model")
    expect(error).to eq(id: "call_1", name: "missing", value: {error: true})
  end

  it "suppresses DSML tool markers from streamed content" do
    parser.parse!(
      {"contentBlockIndex" => 0, "delta" => {"text" => "<｜DSML｜function_calls"}},
      event_type: "contentBlockDelta"
    )
    parser.parse!({"contentBlockIndex" => 0}, event_type: "contentBlockStop")
    expect(stream.content).to eq("")
    expect(parser.body.dig("output", "message", "content", 0)).to eq({})
  end
end
