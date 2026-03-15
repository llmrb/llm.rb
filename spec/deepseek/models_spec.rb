# frozen_string_literal: true

require "setup"

RSpec.describe "LLM::Deepseek::Models" do
  let(:key) { ENV["DEEPSEEK_SECRET"] || "TOKEN" }
  let(:provider) { LLM.deepseek(key:) }

  context "when given a successful list operation",
          vcr: {cassette_name: "deepseek/models/successful_list"} do
    subject(:response) { provider.models.all }

    it "is successful" do
      is_expected.to be_instance_of(LLM::Response)
    end

    include_examples "LLM::Models contract"

    it "marks listed models as supporting chat" do
      expect(response.models.all?(&:chat?)).to be(true)
    end
  end
end
