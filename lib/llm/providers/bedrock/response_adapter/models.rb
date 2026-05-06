# frozen_string_literal: true

module LLM::Bedrock::ResponseAdapter
  ##
  # Adapts Bedrock ListFoundationModels API responses to llm.rb's
  # normalized model collection format.
  #
  # The Bedrock ListFoundationModels response looks like:
  #   {
  #     "modelSummaries": [{
  #       "modelId": "anthropic.claude-sonnet-4-20250514-v1:0",
  #       "modelName": "Claude Sonnet 4",
  #       "providerName": "Anthropic",
  #       "inputModalities": ["TEXT", "IMAGE"],
  #       "outputModalities": ["TEXT"],
  #       ...
  #     }]
  #   }
  module Models
    include LLM::Model::Collection

    private

    def raw_models
      (body.modelSummaries || []).map do |summary|
        LLM::Object.from({
          id: summary.modelId,
          name: summary.modelName,
          provider_name: summary.providerName
        })
      end
    end
  end
end
