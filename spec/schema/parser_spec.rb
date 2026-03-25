# frozen_string_literal: true

require "setup"

RSpec.describe LLM::Schema::Parser do
  describe ".parse" do
    subject(:parse) { LLM::Schema.parse(schema) }

    context "when given an object schema" do
      let(:schema) do
        {
          type: "object",
          description: "person",
          properties: {
            name: {type: "string", description: "name"},
            tags: {
              type: "array",
              items: {type: "string", minLength: 2}
            }
          },
          required: ["name"]
        }
      end

      it "returns an object schema" do
        expect(parse).to be_a(LLM::Schema::Object)
      end

      it "parses nested properties" do
        expect(parse["name"]).to be_a(LLM::Schema::String)
        expect(parse["name"].description).to eq("name")
      end

      it "marks required properties" do
        expect(parse["name"]).to be_required
        expect(parse["tags"]).to_not be_required
      end

      it "parses nested array items" do
        array = parse["tags"]
        expect(array).to be_a(LLM::Schema::Array)
        expect(array.to_h[:type]).to eq("array")
        expect(array.to_h[:items]).to eq(
          LLM::Schema.new.string.min(2)
        )
      end
    end

    context "when given an array schema" do
      let(:schema) do
        {
          type: "array",
          description: "directories",
          items: {
            type: "object",
            properties: {
              path: {type: "string"},
              size: {type: "integer", minimum: 0}
            },
            required: ["path"]
          }
        }
      end

      it "returns an array schema" do
        expect(parse).to be_a(LLM::Schema::Array)
      end

      it "parses the array metadata" do
        expect(parse.to_h[:description]).to eq("directories")
        expect(parse.to_h[:type]).to eq("array")
      end

      it "parses item schemas recursively" do
        item = parse.to_h[:items]
        expect(item).to be_a(LLM::Schema::Object)
        expect(item.keys).to eq(%w[path size])
        expect(item["path"]).to be_required
        expect(item["path"]).to eq(LLM::Schema.new.string)
        expect(item["size"]).to eq(LLM::Schema.new.integer.min(0))
      end
    end

    context "when given scalar metadata" do
      let(:schema) do
        {
          type: "number",
          description: "ratio",
          default: 1,
          enum: [1, 2],
          minimum: 0,
          maximum: 10
        }
      end

      it "applies metadata to the parsed leaf" do
        expect(parse.to_h).to eq(
          description: "ratio",
          default: 1,
          enum: [1, 2],
          type: "number",
          minimum: 0,
          maximum: 10
        )
      end
    end

    context "when given an unsupported schema type" do
      let(:schema) { {type: "nope"} }

      it "raises a type error" do
        expect { parse }.to raise_error(TypeError, /unsupported schema type/)
      end
    end
  end
end
