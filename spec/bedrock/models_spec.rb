# frozen_string_literal: true

require "setup"

RSpec.describe "LLM::Bedrock::Models" do
  let(:provider) do
    LLM.bedrock(
      access_key_id: ENV["AWS_ACCESS_KEY_ID"] || "TOKEN",
      secret_access_key: ENV["AWS_SECRET_ACCESS_KEY"] || "TOKEN",
      region: ENV["AWS_REGION"] || "us-east-1",
      session_token: ENV["AWS_SESSION_TOKEN"]
    )
  end

  context "when given a successful list operation",
          vcr: {cassette_name: "bedrock/models/successful_list"} do
    subject(:response) { provider.models.all }

    it "is successful" do
      is_expected.to be_instance_of(LLM::Response)
    end

    include_examples "LLM::Models contract"
  end
end
