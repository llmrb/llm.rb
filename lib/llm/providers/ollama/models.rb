# frozen_string_literal: true

class LLM::Ollama
  ##
  # The {LLM::Ollama::Models LLM::Ollama::Models} class provides a model
  # object for interacting with [Ollama's models API](https://github.com/ollama/ollama/blob/main/docs/api.md#list-local-models).
  # The models API allows a client to query Ollama for a list of models
  # that are available for use with the Ollama API.
  #
  # @example
  #   #!/usr/bin/env ruby
  #   require "llm"
  #
  #   llm = LLM.ollama(nil)
  #   res = llm.models.all
  #   res.each do |model|
  #     print "id: ", model.id, "\n"
  #   end
  class Models
    include LLM::Utils

    ##
    # Returns a new Models object
    # @param provider [LLM::Provider]
    # @return [LLM::Ollama::Models]
    def initialize(provider)
      @provider = provider
    end

    ##
    # List all models
    # @example
    #   llm = LLM.ollama(nil)
    #   res = llm.models.all
    #   res.each do |model|
    #     print "id: ", model.id, "\n"
    #   end
    # @see https://github.com/ollama/ollama/blob/main/docs/api.md#list-local-models Ollama docs
    # @see https://ollama.com/library Ollama library
    # @param [Hash] params Other parameters (see Ollama docs)
    # @raise (see LLM::Provider#request)
    # @return [LLM::Response]
    def all(**params)
      query = URI.encode_www_form(params)
      req = Net::HTTP::Get.new("/api/tags?#{query}", headers)
      res, span = execute(request: req, operation: "request")
      res = LLM::Response.new(res)
      finish_trace(operation: "request", res:, span:)
    end

    private

    [:headers, :execute, :finish_trace].each do |m|
      define_method(m) { |*args, **kwargs, &b| @provider.send(m, *args, **kwargs, &b) }
    end
  end
end
