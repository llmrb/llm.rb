# frozen_string_literal: true

class LLM::OpenAI
  ##
  # @private
  module ResponseAdapter
    require_relative "response_adapter/audio"
    require_relative "response_adapter/completion"
    require_relative "response_adapter/embedding"
    require_relative "response_adapter/enumerable"
    require_relative "response_adapter/file"
    require_relative "response_adapter/image"
    require_relative "response_adapter/moderations"
    require_relative "response_adapter/models"
    require_relative "response_adapter/responds"
    require_relative "response_adapter/web_search"

    module_function

    ##
    # @param [LLM::Response, Net::HTTPResponse] res
    # @param [Symbol] type
    # @return [LLM::Response]
    def adapt(res, type:)
      response = (LLM::Response === res) ? res : LLM::Response.new(res)
      adapter = select(type)
      response.extend(adapter)
    end

    ##
    # @api private
    def select(type)
      case type
      when :audio then LLM::OpenAI::ResponseAdapter::Audio
      when :completion then LLM::OpenAI::ResponseAdapter::Completion
      when :embedding then LLM::OpenAI::ResponseAdapter::Embedding
      when :enumerable then LLM::OpenAI::ResponseAdapter::Enumerable
      when :file then LLM::OpenAI::ResponseAdapter::File
      when :image then LLM::OpenAI::ResponseAdapter::Image
      when :moderations then LLM::OpenAI::ResponseAdapter::Moderations
      when :models then LLM::OpenAI::ResponseAdapter::Models
      when :responds then LLM::OpenAI::ResponseAdapter::Responds
      when :web_search then LLM::OpenAI::ResponseAdapter::WebSearch
      else
        raise ArgumentError, "Unknown response adapter type: #{type.inspect}"
      end
    end
  end
end
