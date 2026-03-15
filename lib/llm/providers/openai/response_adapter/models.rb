# frozen_string_literal: true

module LLM::OpenAI::ResponseAdapter
  module Models
    include LLM::Model::Collection

    private

    def raw_models
      data || []
    end
  end
end
