# frozen_string_literal: true

require "setup"

RSpec.describe "LLM::OpenAI::Models" do
  let(:key) { ENV["OPENAI_SECRET"] || "TOKEN" }
  let(:provider) { LLM.openai(key:) }

  context "when given a successful list operation",
          vcr: {cassette_name: "openai/models/successful_list"} do
    subject(:response) { provider.models.all }

    it "is successful" do
      is_expected.to be_instance_of(LLM::Response)
    end

    include_examples "LLM::Models contract"
  end
end
