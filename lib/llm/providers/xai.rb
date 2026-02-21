# frozen_string_literal: true

require_relative "openai" unless defined?(LLM::OpenAI)

module LLM
  ##
  # The XAI class implements a provider for [xAI](https://docs.x.ai).
  #
  # @example
  #   #!/usr/bin/env ruby
  #   require "llm"
  #
  #   llm = LLM.xai(key: ENV["KEY"])
  #   ses = LLM::Session.new(llm)
  #   ses.talk ["Tell me about this photo", ses.local_file("/images/photo.png")]
  #   ses.messages.select(&:assistant?).each { print "[#{_1.role}]", _1.content, "\n" }
  class XAI < OpenAI
    require_relative "xai/images"

    ##
    # @param [String] host A regional host or the default ("api.x.ai")
    # @param key (see LLM::Provider#initialize)
    # @see https://docs.x.ai/docs/key-information/regions Regional endpoints
    def initialize(host: "api.x.ai", **)
      super
    end

    ##
    # @raise [NotImplementedError]
    def files
      raise NotImplementedError
    end

    ##
    # @return [LLM::XAI::Images]
    def images
      LLM::XAI::Images.new(self)
    end

    ##
    # @raise [NotImplementedError]
    def audio
      raise NotImplementedError
    end

    ##
    # @raise [NotImplementedError]
    def moderations
      raise NotImplementedError
    end

    ##
    # @raise [NotImplementedError]
    def responses
      raise NotImplementedError
    end

    ##
    # @raise [NotImplementedError]
    def vector_stores
      raise NotImplementedError
    end

    ##
    # Returns the default model for chat completions
    # #see https://docs.x.ai/docs/models grok-4-0709
    # @return [String]
    def default_model
      "grok-4-0709"
    end
  end
end
