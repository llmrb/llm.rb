# frozen_string_literal: true

class LLM::Ollama
  ##
  # @private
  module ResponseAdapter
    require_relative "response_adapter/completion"
    require_relative "response_adapter/embedding"
    require_relative "response_adapter/models"

    module_function

    ##
    # @param [LLM::Response, Net::HTTPResponse] res
    # @param [Symbol] type
    # @return [LLM::Response]
    def adapt(res, type:)
      response = (LLM::Response === res) ? res : LLM::Response.new(res)
      response.extend(select(type))
    end

    ##
    # @api private
    def select(type)
      case type
      when :completion then LLM::Ollama::ResponseAdapter::Completion
      when :embedding then LLM::Ollama::ResponseAdapter::Embedding
      when :models then LLM::Ollama::ResponseAdapter::Models
      else
        raise ArgumentError, "Unknown response adapter type: #{type.inspect}"
      end
    end
  end
end
