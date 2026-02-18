# frozen_string_literal: true

class LLM::Anthropic
  ##
  # The {LLM::Anthropic::Models LLM::Anthropic::Models} class provides a model
  # object for interacting with [Anthropic's models API](https://platform.anthropic.com/docs/api-reference/models/list).
  # The models API allows a client to query Anthropic for a list of models
  # that are available for use with the Anthropic API.
  #
  # @example
  #   #!/usr/bin/env ruby
  #   require "llm"
  #
  #   llm = LLM.anthropic(key: ENV["KEY"])
  #   res = llm.models.all
  #   res.each do |model|
  #     print "id: ", model.id, "\n"
  #   end
  class Models
    ##
    # Returns a new Models object
    # @param provider [LLM::Provider]
    # @return [LLM::Anthropic::Files]
    def initialize(provider)
      @provider = provider
    end

    ##
    # List all models
    # @example
    #   llm = LLM.anthropic(key: ENV["KEY"])
    #   res = llm.models.all
    #   res.each do |model|
    #     print "id: ", model.id, "\n"
    #   end
    # @see https://docs.anthropic.com/en/api/models-list Anthropic docs
    # @param [Hash] params Other parameters (see Anthropic docs)
    # @raise (see LLM::Provider#request)
    # @return [LLM::Response]
    def all(**params)
      query = URI.encode_www_form(params)
      req = Net::HTTP::Get.new("/v1/models?#{query}", headers)
      res, span = execute(request: req, operation: "request")
      res = ResponseAdapter.adapt(res, type: :enumerable)
      finish_trace(operation: "request", res:, span:)
    end

    private

    [:headers, :execute, :finish_trace].each do |m|
      define_method(m) { |*args, **kwargs, &b| @provider.send(m, *args, **kwargs, &b) }
    end
  end
end
