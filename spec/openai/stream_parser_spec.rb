# frozen_string_literal: true

require "setup"
require "llm/providers/openai"

RSpec.describe LLM::OpenAI::StreamParser do
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

  it "accumulates content and reasoning deltas into one message" do
    parser.parse!("choices" => [{"index" => 0, "delta" => {"content" => +"Hel"}}])
    parser.parse!("choices" => [{"index" => 0, "delta" => {"content" => +"lo"}}])
    parser.parse!("choices" => [{"index" => 0, "delta" => {"reasoning_content" => +"Think"}}])
    expect(parser.body.dig("choices", 0, "message", "content")).to eq("Hello")
    expect(parser.body.dig("choices", 0, "message", "reasoning_content")).to eq("Think")
    expect(stream.content).to eq("Hello")
    expect(stream.reasoning_content).to eq("Think")
  end

  it "emits tool calls after arguments become complete" do
    stream.extra[:tracer] = Object.new
    stream.extra[:model] = "deepseek-chat"
    parser.parse!(
      "choices" => [
        {
          "index" => 0,
          "delta" => {
            "tool_calls" => [
              {
                "index" => 0,
                "id" => "call_1",
                "function" => {"name" => "missing", "arguments" => +"{\"command\""}
              }
            ]
          }
        }
      ]
    )
    parser.parse!(
      "choices" => [
        {
          "index" => 0,
          "delta" => {
            "tool_calls" => [
              {
                "index" => 0,
                "function" => {"arguments" => +":\"date\"}"}
              }
            ]
          }
        }
      ]
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
