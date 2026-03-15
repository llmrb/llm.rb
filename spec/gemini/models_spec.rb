# frozen_string_literal: true

require "setup"

RSpec.describe "LLM::Gemini::Models" do
  let(:key) { ENV["GEMINI_SECRET"] || "TOKEN" }
  let(:provider) { LLM.gemini(key:) }

  context "when given a successful list operation",
          vcr: {cassette_name: "gemini/models/successful_list", match_requests_on: [:method]} do
    subject(:response) { provider.models.all }

    it "is successful" do
      is_expected.to be_instance_of(LLM::Response)
    end

    include_examples "LLM::Models contract"

    it "derives chat support from generation methods" do
      expect(response.models.find { _1.id == "gemini-2.5-flash" }&.chat?).to be(true)
      expect(response.models.select { ["gemini-embedding-001", "imagen-4.0-generate-001"].include?(_1.id) }
        .none?(&:chat?)).to be(true)
    end
  end
end
