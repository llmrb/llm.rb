# frozen_string_literal: true

class LLM::MCP
  class Error < LLM::Error
    attr_reader :code, :data

    ##
    # @param [Hash] response
    #  The full response from the MCP process, including the error object
    # @return [LLM::MCP::Error]
    def self.from(response:)
      error = response.fetch("error")
      new(*error.values_at("message", "code", "data"))
    end

    ##
    # @param [String] message
    #  The error message
    # @param [Integer] code
    #  The error code
    # @param [Object] data
    #  Additional error data provided by the MCP process
    def initialize(message, code = nil, data = nil)
      super(message)
      @code = code
      @data = data
    end
  end

  TimeoutError = Class.new(Error)
end
