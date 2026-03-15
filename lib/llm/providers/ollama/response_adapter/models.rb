# frozen_string_literal: true

module LLM::Ollama::ResponseAdapter
  module Models
    include LLM::Model::Collection

    private

    def raw_models
      body.models || []
    end
  end
end
