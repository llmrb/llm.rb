# frozen_string_literal: true

require "setup"

RSpec.describe "LLM::Bot: anthropic" do
  let(:described_class) { LLM::Bot }
  let(:provider) { LLM.anthropic(key:) }
  let(:llm) { provider }
  let(:key) { ENV["ANTHROPIC_SECRET"] || "TOKEN" }
  let(:bot) { described_class.new(provider, params) }
  let(:params) { {} }

  context LLM do
    include_examples "LLM: web search", :anthropic
  end

  context LLM::Bot do
    include_examples "LLM::Bot: completions", :anthropic
    include_examples "LLM::Bot: completions contract", :anthropic
    include_examples "LLM::Bot: text stream", :anthropic
    include_examples "LLM::Bot: tool stream", :anthropic
  end

  context LLM::Function do
    include_examples "LLM::Bot: functions", :anthropic
  end

  context LLM::File do
    include_examples "LLM::Bot: files", :anthropic
  end
end
