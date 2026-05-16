# frozen_string_literal: true

require "setup"
require "llm/providers/openai"

RSpec.describe LLM::OpenAI::Responses::StreamParser do
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
    end.new
  end

  subject(:parser) { described_class.new(stream) }

  after { parser.free }
  before { LLM::Tool.clear_registry! }

  it "accumulates reasoning summaries and output text deltas" do
    parser.parse!(
      "type" => "response.output_item.added",
      "output_index" => 0,
      "item" => {"id" => "rs_1", "type" => "reasoning", "summary" => []}
    )
    parser.parse!(
      "type" => "response.reasoning_summary_text.delta",
      "output_index" => 0,
      "summary_index" => 0,
      "delta" => "Think"
    )
    parser.parse!(
      "type" => "response.output_item.added",
      "output_index" => 1,
      "item" => {"id" => "msg_1", "type" => "message", "content" => []}
    )
    parser.parse!(
      "type" => "response.content_part.added",
      "output_index" => 1,
      "content_index" => 0,
      "part" => {"type" => "output_text", "text" => +""}
    )
    parser.parse!(
      "type" => "response.output_text.delta",
      "output_index" => 1,
      "content_index" => 0,
      "delta" => "Answer"
    )
    expect(parser.body.dig("output", 0, "summary", 0, "text")).to eq("Think")
    expect(parser.body.dig("output", 1, "content", 0, "text")).to eq("Answer")
    expect(stream.reasoning_content).to eq("Think")
    expect(stream.content).to eq("Answer")
  end

  it "refreshes cached content when an output item is replaced" do
    parser.parse!(
      "type" => "response.output_item.added",
      "output_index" => 0,
      "item" => {"id" => "msg_1", "type" => "message", "content" => []}
    )
    parser.parse!(
      "type" => "response.content_part.added",
      "output_index" => 0,
      "content_index" => 0,
      "part" => {"type" => "output_text", "text" => +""}
    )
    parser.parse!(
      "type" => "response.output_text.delta",
      "output_index" => 0,
      "content_index" => 0,
      "delta" => "A"
    )
    parser.parse!(
      "type" => "response.output_item.done",
      "output_index" => 0,
      "item" => {
        "id" => "msg_1",
        "type" => "message",
        "content" => [{"type" => "output_text", "text" => +"B"}]
      }
    )
    parser.parse!(
      "type" => "response.output_text.delta",
      "output_index" => 0,
      "content_index" => 0,
      "delta" => "C"
    )
    expect(parser.body.dig("output", 0, "content", 0, "text")).to eq("BC")
  end

  it "emits tool calls when response function arguments complete" do
    stream.extra[:tracer] = Object.new
    stream.extra[:model] = "deepseek-chat"
    parser.parse!(
      "type" => "response.output_item.added",
      "output_index" => 0,
      "item" => {
        "id" => "fc_1",
        "type" => "function_call",
        "status" => "in_progress",
        "arguments" => +"",
        "call_id" => "call_1",
        "name" => "missing"
      }
    )
    parser.parse!(
      "type" => "response.function_call_arguments.delta",
      "output_index" => 0,
      "delta" => +"{\"command\""
    )
    parser.parse!(
      "type" => "response.function_call_arguments.done",
      "output_index" => 0,
      "arguments" => "{\"command\":\"date\"}"
    )
    fn, error = stream.calls.fetch(0)
    expect(fn.id).to eq("call_1")
    expect(fn.name).to eq("missing")
    expect(fn.arguments).to eq({"command" => "date"})
    expect(fn.tracer).to equal(stream.extra[:tracer])
    expect(fn.model).to eq("deepseek-chat")
    expect(error.to_h).to eq(
      id: "call_1", name: "missing",
      value: {error: true, type: "LLM::NoSuchToolError", message: "tool not found"}
    )
  end
end
