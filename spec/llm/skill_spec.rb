# frozen_string_literal: true

require_relative "../setup"
require "tmpdir"

RSpec.describe LLM::Skill do
  class WeatherTool < LLM::Tool
    name "weather"
    description "Get the current weather"

    def call(**)
      {content: "sunny"}
    end
  end

  around do |example|
    Dir.mktmpdir do |dir|
      @dir = dir
      example.run
    end
  end

  before do
    LLM::Tool.clear_registry!
    LLM::Tool.register(WeatherTool)
  end

  let(:skill_dir) { File.join(@dir, "weather") }
  let(:provider) { double("provider", default_model: "gpt-5.4-mini") }

  def write(path, content)
    full = File.join(skill_dir, path)
    FileUtils.mkdir_p(File.dirname(full))
    File.write(full, content)
  end

  describe ".load" do
    before do
      write("SKILL.md", <<~MD)
        ---
        name: weather
        description: Get the current weather
        ---
        Use the helper tools to answer the user's question.
      MD
    end

    subject(:skill) { described_class.load(skill_dir) }

    it "loads metadata from SKILL.md" do
      expect(skill.name).to eq("weather")
      expect(skill.description).to eq("Get the current weather")
      expect(skill.frontmatter.name).to eq("weather")
      expect(skill.frontmatter.description).to eq("Get the current weather")
    end

    it "exposes the instructions body" do
      expect(skill.instructions).to include("Use the helper tools")
    end

    it "loads tools from SKILL.md" do
      write("SKILL.md", <<~MD)
        ---
        name: weather
        description: Get the current weather
        tools:
          - weather
        ---
        Use the helper tools to answer the user's question.
      MD
      expect(skill.tools).to eq([WeatherTool])
    end

    it "raises when a tool is missing" do
      write("SKILL.md", <<~MD)
        ---
        tools:
          - missing
        ---
        Use the helper tools to answer the user's question.
      MD
      expect { described_class.load(skill_dir) }.to raise_error(LLM::NoSuchToolError, /missing/)
    end
  end

  describe "#to_tool" do
    before do
      write("SKILL.md", <<~MD)
        ---
        name: weather
        description: Get the current weather
        tools:
          - weather
        ---
        Use the helper tools.
      MD
    end

    let(:skill) { described_class.load(skill_dir) }
    let(:tool) { skill.to_tool(provider) }

    it "builds a tool with the skill metadata" do
      expect(tool.name).to eq("weather")
      expect(tool.description).to eq("Get the current weather")
    end

    it "binds tool execution back to the skill" do
      expect(skill).to receive(:call).with(provider, location: "London").and_return({content: "rain"})
      expect(tool.new.call(location: "London")).to eq({content: "rain"})
    end
  end

  describe "#call" do
    before do
      write("SKILL.md", <<~MD)
        ---
        name: weather
        description: Get the current weather
        ---
        Use the helper tools.
      MD
    end

    let(:skill) { described_class.load(skill_dir) }
    let(:response) { double("response", content: "It is raining") }

    it "uses an internal agent and returns tool-shaped output" do
      allow_any_instance_of(LLM::Agent).to receive(:talk).with("Use the helper tools.\n").and_return(response)
      expect(skill.call(provider, location: "London")).to eq({content: "It is raining"})
    end
  end
end
