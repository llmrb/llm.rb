# frozen_string_literal: true

require_relative "openai" unless defined?(LLM::OpenAI)

module LLM
  ##
  # The LlamaCpp class implements a provider for
  # [llama.cpp](https://github.com/ggml-org/llama.cpp)
  # through the OpenAI-compatible API provided by the
  # llama-server binary. Similar to the ollama provider,
  # this provider supports a wide range of models and
  # is straightforward to run on your own hardware.
  #
  # @example
  #   #!/usr/bin/env ruby
  #   require "llm"
  #
  #   llm = LLM.llamacpp(key: nil)
  #   ses = LLM::Session.new(llm)
  #   ses.talk ["Tell me about this photo", ses.local_file("/images/photo.png")]
  #   ses.messages.select(&:assistant?).each { print "[#{_1.role}]", _1.content, "\n" }
  class LlamaCpp < OpenAI
    ##
    # @param (see LLM::Provider#initialize)
    # @return [LLM::LlamaCpp]
    def initialize(host: "localhost", port: 8080, ssl: false, **)
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
    # @see https://ollama.com/library/qwen3 qwen3
    # @return [String]
    def default_model
      "qwen3"
    end
  end
end
