# frozen_string_literal: true

require_relative "openai" unless defined?(LLM::OpenAI)

module LLM
  ##
  # The DeepSeek class implements a provider for
  # [DeepSeek](https://deepseek.com)
  # through its OpenAI-compatible API available via
  # their [web platform](https://platform.deepseek.com).
  #
  # @example
  #   #!/usr/bin/env ruby
  #   require "llm"
  #
  #   llm = LLM.deepseek(key: ENV["KEY"])
  #   ses = LLM::Session.new(llm)
  #   ses.talk ["Tell me about this photo", ses.local_file("/images/photo.png")]
  #   ses.messages.select(&:assistant?).each { print "[#{_1.role}]", _1.content, "\n" }
  class DeepSeek < OpenAI
    require_relative "deepseek/request_adapter"
    include DeepSeek::RequestAdapter

    ##
    # @param (see LLM::Provider#initialize)
    # @return [LLM::DeepSeek]
    def initialize(host: "api.deepseek.com", port: 443, ssl: true, **)
      super
    end

    ##
    # @raise [NotImplementedError]
    def files
      raise NotImplementedError
    end

    ##
    # @raise [NotImplementedError]
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
    # @see https://api-docs.deepseek.com/quick_start/pricing deepseek-chat
    # @return [String]
    def default_model
      "deepseek-chat"
    end
  end
end
