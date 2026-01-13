# frozen_string_literal: true

class LLM::OpenAI
  ##
  # @private
  class ErrorHandler
    ##
    # @return [Net::HTTPResponse]
    #  Non-2XX response from the server
    attr_reader :res

    ##
    # @param [Net::HTTPResponse] res
    #  The response from the server
    # @return [LLM::OpenAI::ErrorHandler]
    def initialize(res)
      @res = res
    end

    ##
    # @raise [LLM::Error]
    #  Raises a subclass of {LLM::Error LLM::Error}
    def raise_error!
      case res
      when Net::HTTPServerError
        raise LLM::ServerError.new { _1.response = res }, "Server error"
      when Net::HTTPUnauthorized
        raise LLM::UnauthorizedError.new { _1.response = res }, "Authentication error"
      when Net::HTTPTooManyRequests
        raise LLM::RateLimitError.new { _1.response = res }, "Too many requests"
      else
        error = body["error"] || {}
        case error["type"]
        when "server_error" then raise LLM::ServerError.new { _1.response = res }, error["message"]
        when "invalid_request_error" then handle_invalid_request(error)
        else raise LLM::ResponseError.new { _1.response = res }, error["message"] || "Unexpected response"
        end
      end
    end

    private

    def handle_invalid_request(error)
      case error["code"]
      when "context_length_exceeded"
        raise LLM::ContextWindowError.new { _1.response = res }, error["message"]
      else
        raise LLM::InvalidRequestError.new { _1.response = res }, error["message"]
      end
    end

    def body
      @body ||= JSON.parse(res.body)
    end
  end
end
