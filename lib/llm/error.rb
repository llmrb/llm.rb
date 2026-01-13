# frozen_string_literal: true

module LLM
  ##
  # The superclass of all LLM errors
  class Error < RuntimeError
    def initialize(...)
      block_given? ? yield(self) : nil
      super
    end
  end

  ##
  # The superclass of all HTTP protocol errors
  class ResponseError < Error
    ##
    # @return [Net::HTTPResponse]
    #  Returns the response associated with an error
    attr_accessor :response

    def message
      [super, response.body].join("\n")
    end
  end

  ##
  # HTTPUnauthorized
  UnauthorizedError = Class.new(ResponseError)

  ##
  # HTTPTooManyRequests
  RateLimitError = Class.new(ResponseError)

  ##
  # HTTPServerError
  ServerError = Class.new(ResponseError)

  ##
  # When no images are found in a response
  NoImageError = Class.new(ResponseError)

  ##
  # When an given an input object that is not understood
  FormatError = Class.new(Error)

  ##
  # When given a prompt object that is not understood
  PromptError = Class.new(FormatError)

  ##
  # When given an invalid request
  InvalidRequestError = Class.new(Error) do
    attr_accessor :response
  end

  ##
  # When the context window is exceeded
  ContextWindowError = Class.new(InvalidRequestError)
end
