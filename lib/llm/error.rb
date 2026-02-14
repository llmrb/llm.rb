# frozen_string_literal: true

module LLM
  ##
  # The superclass of all LLM errors
  class Error < RuntimeError
    ##
    # @return [Net::HTTPResponse, nil]
    #  Returns the response associated with an error, or nil
    attr_accessor :response

    def initialize(...)
      block_given? ? yield(self) : nil
      super
    end

    def message
      if response
        [super, response.body].join("\n")
      else
        super
      end
    end
  end

  ##
  # HTTPUnauthorized
  UnauthorizedError = Class.new(Error)

  ##
  # HTTPTooManyRequests
  RateLimitError = Class.new(Error)

  ##
  # HTTPServerError
  ServerError = Class.new(Error)

  ##
  # When an given an input object that is not understood
  FormatError = Class.new(Error)

  ##
  # When given a prompt object that is not understood
  PromptError = Class.new(FormatError)

  ##
  # When given an invalid request
  InvalidRequestError = Class.new(Error)

  ##
  # When the context window is exceeded
  ContextWindowError = Class.new(InvalidRequestError)

  ##
  # When stuck in a tool call loop
  ToolLoopError = Class.new(Error)
end
