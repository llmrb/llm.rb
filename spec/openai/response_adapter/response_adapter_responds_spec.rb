# frozen_string_literal: true

require "setup"

RSpec.describe "LLM::OpenAI::ResponseAdapter::Responds" do
  let!(:provider) { LLM.openai(key: "test") }
  let(:body) do
    LLM::Object.from(
      model: "test-model",
      usage: {
        input_tokens_details: {audio_tokens: 2},
        output_tokens_details: {audio_tokens: 3}
      },
      output: [
        {
          type: "message",
          content: [
            {type: "output_text", text: "hello"}
          ]
        },
        {
          type: "function_call",
          call_id: "call_1",
          name: "system",
          arguments: "{\"command\":\"date"
        }
      ]
    )
  end
  let(:http_response) { Struct.new(:body).new(body) }
  let(:response) { LLM::Response.new(http_response) }
  let(:responds) { LLM::OpenAI::ResponseAdapter.adapt(response, type: :responds) }

  it "tolerates malformed tool arguments" do
    expect(responds.choices[0].extra[:tool_calls]).to eq(
      [{id: "call_1", name: "system", arguments: {}}]
    )
  end

  it "exposes content like a completion response" do
    expect(responds.content).to eq("hello\n")
  end

  it "returns audio token details" do
    expect(responds.input_audio_tokens).to eq(2)
    expect(responds.output_audio_tokens).to eq(3)
  end

  it "returns 0 for input image tokens" do
    expect(responds.input_image_tokens).to eq(0)
  end
end
