# frozen_string_literal: true

require_relative "openai" unless defined?(LLM::OpenAI)

module LLM
  ##
  # The ZAI class implements a provider for [zAI](https://docs.z.ai/guides/overview/quick-start).
  #
  # @example
  #   #!/usr/bin/env ruby
  #   require "llm"
  #
  #   llm = LLM.zai(key: ENV["KEY"])
  #   ses = LLM::Session.new(llm, stream: $stdout)
  #   ses.talk "Hello"
  class ZAI < OpenAI
    ##
    # @param [String] host A regional host or the default ("api.z.ai")
    # @param key (see LLM::Provider#initialize)
    def initialize(host: "api.z.ai", **)
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
      raise NotImplementedError
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
    # #see https://docs.z.ai/guides/llm/glm-4.5#glm-4-5-flash glm-4.5-flash
    # @return [String]
    def default_model
      "glm-4.5-flash"
    end

    private

    def completions_path
      "/api/paas/v4/chat/completions"
    end
  end
end
