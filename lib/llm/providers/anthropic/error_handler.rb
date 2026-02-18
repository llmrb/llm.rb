# frozen_string_literal: true

class LLM::Anthropic
  ##
  # @private
  class ErrorHandler
    ##
    # @return [Net::HTTPResponse]
    #  Non-2XX response from the server
    attr_reader :res

    ##
    # @return [Object, nil]
    #  The span
    attr_reader :span

    ##
    # @param [LLM::Tracer] tracer
    #  The tracer
    # @param [Object, nil] span
    #  The span
    # @param [Net::HTTPResponse] res
    #  The response from the server
    # @return [LLM::Anthropic::ErrorHandler]
    def initialize(tracer, span, res)
      @tracer = tracer
      @span = span
      @res = res
    end

    ##
    # @raise [LLM::Error]
    #  Raises a subclass of {LLM::Error LLM::Error}
    def raise_error!
      ex = error
      @tracer.on_request_error(ex:, span:)
    ensure
      raise(ex)
    end

    private

    ##
    # @return [LLM::Error]
    def error
      case res
      when Net::HTTPServerError
        LLM::ServerError.new("Server error").tap { _1.response = res }
      when Net::HTTPUnauthorized
        LLM::UnauthorizedError.new("Authentication error").tap { _1.response = res }
      when Net::HTTPTooManyRequests
        LLM::RateLimitError.new("Too many requests").tap { _1.response = res }
      else
        LLM::Error.new("Unexpected response").tap { _1.response = res }
      end
    end
  end
end
