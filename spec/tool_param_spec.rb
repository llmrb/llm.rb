# frozen_string_literal: true

require_relative "setup"

RSpec.describe LLM::Tool::Param do
  context "when given enum values for a param" do
    let(:tool) do
      Class.new(LLM::Tool) do
        name "create-image"
        description "Create a generated image"
        param :provider, String, "The provider", enum: %w[openai google], default: "google"
      end
    end

    subject(:provider_param) { tool.function.params.properties[:provider] }

    it "serializes the enum as a flat array" do
      expect(provider_param.to_h[:enum]).to eq(%w[openai google])
    end

    it "preserves the default value" do
      expect(provider_param.to_h[:default]).to eq("google")
    end
  end

  context "when given Enum[...] as the param type" do
    let(:tool) do
      stub_const("EnumTool", Module.new)
      EnumTool.const_set(:Enum, LLM::Schema::Enum)
      EnumTool.module_eval(<<~RUBY, __FILE__, __LINE__ + 1)
        class Tool < LLM::Tool
          name "create-image"
          description "Create a generated image"
          param :provider, Enum["openai", "google"], "The provider"
        end
      RUBY
      EnumTool::Tool
    end

    subject(:provider_param) { tool.function.params.properties[:provider] }

    it "builds a string param with enum values" do
      expect(provider_param).to be_a(LLM::Schema::String)
      expect(provider_param.to_h[:enum]).to eq(%w[openai google])
    end
  end

  context "when given Array[...] as the param type" do
    let(:tool) do
      Class.new(LLM::Tool) do
        name "man-search"
        description "Search the manual pages for keyword(s)"
        parameter :keywords, Array[String], "One or more keywords to search for"
      end
    end

    context "when reading the keywords param" do
      subject(:keywords_param) { tool.function.params.properties[:keywords] }

      it "builds an array param" do
        expect(keywords_param).to be_a(LLM::Schema::Array)
      end

      it "builds the nested item type" do
        expect(keywords_param.to_h[:items]).to eq(LLM::Schema.new.string)
      end
    end
  end

  context "when given a mixed Array[...] param type" do
    let(:tool) do
      Class.new(LLM::Tool) do
        name "mixed-array"
        description "Accepts mixed array values"
        parameter :values, Array[String, Integer], "Mixed values"
      end
    end

    context "when reading the values param" do
      subject(:values_param) { tool.function.params.properties[:values] }

      it "builds an array param" do
        expect(values_param).to be_a(LLM::Schema::Array)
      end

      it "builds anyOf items" do
        expect(values_param.to_h[:items]).to eq(
          LLM::Schema.new.any_of(LLM::Schema.new.string, LLM::Schema.new.integer)
        )
      end
    end
  end

  context "when using parameter as an alias of param" do
    let(:tool) do
      Class.new(LLM::Tool) do
        name "weather"
        description "Lookup the weather for a location"
        parameter :location, String, "A location"
      end
    end

    subject(:location_param) { tool.function.params.properties[:location] }

    it "defines the parameter" do
      expect(location_param).to be_a(LLM::Schema::String)
    end

    it "preserves the description" do
      expect(location_param.description).to eq("A location")
    end
  end

  context "when required fields are declared separately" do
    let(:tool) do
      Class.new(LLM::Tool) do
        name "weather"
        description "Lookup the weather for a location"
        parameter :location, String, "A location"
        required %i[location]
      end
    end

    subject(:schema) { tool.function.params }

    it "marks the parameter as required" do
      expect(schema.properties[:location]).to be_required
    end

    it "serializes the required field list" do
      expect(schema.to_h[:required]).to eq([:location])
    end
  end
end
