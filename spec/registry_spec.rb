# frozen_string_literal: true

require "setup"

RSpec.describe LLM::Registry do
  let(:registry) { LLM::Registry.for(provider) }

  shared_examples "model exists" do |model|
    context "#cost" do
      context "when given the #{model} model" do
        it "returns an object" do
          expect(
            registry.cost(model:)
          ).to be_instance_of(LLM::Object)
        end
      end
    end
  end

  shared_examples "fallback exists" do |model, fallback|
    context "#cost" do
      context "when given the #{model} model" do
        it "returns the #{fallback} cost object" do
          expect(
            registry.cost(model:)
          ).to eq(registry.cost(model: fallback))
        end
      end
    end
  end

  context "when given openai" do
    let(:provider) { :openai }

    include_examples "model exists", "gpt-4.1"
    include_examples "model exists", "gpt-5.3-codex"
    include_examples "fallback exists", "gpt-4.1-2025-01-01", "gpt-4.1"
    include_examples "fallback exists", "gpt-4-0613", "gpt-4"
  end

  context "when given google" do
    let(:provider) { :google }

    include_examples "model exists", "gemini-3.1-pro-preview-customtools"
    include_examples "model exists", "gemini-embedding-001"
  end

  context "when given anthropic" do
    let(:provider) { :anthropic }

    include_examples "model exists", "claude-opus-4-1"
    include_examples "model exists", "claude-3-5-haiku-latest"
  end

  context "when given deepseek" do
    let(:provider) { :deepseek }

    include_examples "model exists", "deepseek-chat"
    include_examples "model exists", "deepseek-reasoner"
  end

  context "when given xai" do
    let(:provider) { :xai }

    include_examples "model exists", "grok-2"
    include_examples "model exists", "grok-4.20-0309-non-reasoning"
  end

  context "when given zai" do
    let(:provider) { :zai }

    include_examples "model exists", "glm-5"
    include_examples "model exists", "glm-4.5-air"
  end

  context "when given bedrock" do
    let(:provider) { :bedrock }

    include_examples "model exists", "anthropic.claude-sonnet-4-20250514-v1:0"
    include_examples "model exists", "meta.llama3-2-90b-instruct-v1:0"
  end
end
