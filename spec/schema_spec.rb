# frozen_string_literal: true

require_relative "setup"

RSpec.describe LLM::Schema do
  context "when given a schema" do
    let(:all_properties) { [*required_properties, *unrequired_properties] }
    let(:required_properties) { %w[name age height] }
    let(:unrequired_properties) { %w[active location addresses] }

    let(:schema) do
      Class.new(LLM::Schema) do
        property :name, LLM::Schema::String, "name description", required: true
        property :age, LLM::Schema::Integer, "age description", required: true
        property :height, LLM::Schema::Number, "height description", required: true
        property :active, LLM::Schema::Boolean, "active description"
        property :location, LLM::Schema::Null, "location description"
        property :addresses, LLM::Schema::Array[LLM::Schema::String], "addresses description"
      end
    end

    it "has properties" do
      expect(schema.object.keys).to eq(all_properties)
    end

    it "sets properties" do
      all_properties.each { expect(schema.object[_1].description).to eq("#{_1} description") }
      required_properties.each { expect(schema.object[_1]).to be_required }
      unrequired_properties.each { expect(schema.object[_1]).to_not be_required }
    end

    it "configures an array" do
      array = schema.object["addresses"]
      schema = self.schema.schema
      expect(array).to eq(
        schema.array(schema.string).description("addresses description")
      )
    end
  end

  context "when given nested schema classes" do
    let(:address_schema) do
      Class.new(LLM::Schema) do
        property :street, String, "street description", required: true
      end
    end

    let(:person_schema) do
      address = address_schema
      Class.new(LLM::Schema) do
        property :name, String, "name description", required: true
        property :address, address, "address description", required: true
      end
    end

    context "when given the address" do
      subject(:address) { person_schema.object["address"] }

      it "is configured properly" do
        expect(address).to be_a(LLM::Schema::Object)
        expect(address.description).to eq("address description")
        expect(address).to be_required
        expect(address.keys).to eq(["street"])
      end
    end

    context "when given the street" do
      subject(:street) { person_schema.object["address"]["street"] }

      it "is configured properly" do
        expect(street).to be_a(LLM::Schema::String)
        expect(street.description).to eq("street description")
        expect(street).to be_required
      end
    end

    it "requires certain keys" do
      object = person_schema.object
      expect(object.to_h[:required]).to eq(%w[name address])
      expect(object["address"].to_h[:required]).to eq(["street"])
    end
  end
end
