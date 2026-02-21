# frozen_string_literal: true

module LLM
  ##
  # The Ollama class implements a provider for [Ollama](https://ollama.ai/) &ndash;
  # and the provider supports a wide range of models. It is straight forward
  # to run on your own hardware, and there are a number of multi-modal models
  # that can process both images and text.
  #
  # @example
  #   #!/usr/bin/env ruby
  #   require "llm"
  #
  #   llm = LLM.ollama(key: nil)
  #   ses = LLM::Session.new(llm, model: "llava")
  #   ses.talk ["Tell me about this image", ses.local_file("/images/photo.png")]
  #   ses.messages.select(&:assistant?).each { print "[#{_1.role}]", _1.content, "\n" }
  class Ollama < Provider
    require_relative "ollama/error_handler"
    require_relative "ollama/request_adapter"
    require_relative "ollama/response_adapter"
    require_relative "ollama/stream_parser"
    require_relative "ollama/models"

    include RequestAdapter

    HOST = "localhost"

    ##
    # @param key (see LLM::Provider#initialize)
    def initialize(**)
      super(host: HOST, port: 11434, ssl: false, **)
    end

    ##
    # Provides an embedding
    # @param input (see LLM::Provider#embed)
    # @param model (see LLM::Provider#embed)
    # @param params (see LLM::Provider#embed)
    # @raise (see LLM::Provider#request)
    # @return [LLM::Response]
    def embed(input, model: default_model, **params)
      params   = {model:}.merge!(params)
      req      = Net::HTTP::Post.new("/v1/embeddings", headers)
      req.body = LLM.json.dump({input:}.merge!(params))
      res, span = execute(request: req, operation: "embeddings", model:)
      res = ResponseAdapter.adapt(res, type: :embedding)
      finish_trace(operation: "embeddings", model:, res:, span:)
    end

    ##
    # Provides an interface to the chat completions API
    # @see https://github.com/ollama/ollama/blob/main/docs/api.md#generate-a-chat-completion Ollama docs
    # @param prompt (see LLM::Provider#complete)
    # @param params (see LLM::Provider#complete)
    # @example (see LLM::Provider#complete)
    # @raise (see LLM::Provider#request)
    # @raise [LLM::PromptError]
    #  When given an object a provider does not understand
    # @return [LLM::Response]
    def complete(prompt, params = {})
      params, stream, tools, role = normalize_complete_params(params)
      req = build_complete_request(prompt, params, role)
      res, span = execute(request: req, stream: stream, operation: "chat", model: params[:model])
      res = ResponseAdapter.adapt(res, type: :completion)
        .extend(Module.new { define_method(:__tools__) { tools } })
      finish_trace(operation: "chat", model: params[:model], res:, span:)
    end

    ##
    # Provides an interface to Ollama's models API
    # @see https://github.com/ollama/ollama/blob/main/docs/api.md#list-local-models Ollama docs
    # @return [LLM::Ollama::Models]
    def models
      LLM::Ollama::Models.new(self)
    end

    ##
    # @return (see LLM::Provider#assistant_role)
    def assistant_role
      "assistant"
    end

    ##
    # Returns the default model for chat completions
    # @see https://ollama.com/library/qwen3 qwen3
    # @return [String]
    def default_model
      "qwen3:latest"
    end

    private

    def headers
      (@headers || {}).merge(
        "Content-Type" => "application/json",
        "Authorization" => "Bearer #{@key}"
      )
    end

    def stream_parser
      LLM::Ollama::StreamParser
    end

    def error_handler
      LLM::Ollama::ErrorHandler
    end

    def normalize_complete_params(params)
      params = {role: :user, model: default_model, stream: true}.merge!(params)
      tools  = resolve_tools(params.delete(:tools))
      params = [params, {format: params[:schema]}, adapt_tools(tools)].inject({}, &:merge!).compact
      role, stream = params.delete(:role), params.delete(:stream)
      params[:stream] = true if stream.respond_to?(:<<) || stream == true
      [params, stream, tools, role]
    end

    def build_complete_request(prompt, params, role)
      messages = [*(params.delete(:messages) || []), LLM::Message.new(role, prompt)]
      body = LLM.json.dump({messages: [adapt(messages)].flatten}.merge!(params))
      req = Net::HTTP::Post.new("/api/chat", headers)
      set_body_stream(req, StringIO.new(body))
      req
    end
  end
end
