# frozen_string_literal: true

module LLM
  ##
  # The Bedrock class implements a provider for
  # [Amazon Bedrock](https://aws.amazon.com/bedrock/).
  #
  # Bedrock provides access to foundation models from Anthropic, Meta,
  # Mistral, AI21 Labs, Cohere, and more through the AWS infrastructure.
  # This provider uses the Bedrock Converse API for chat completions,
  # and the Converse Stream API for streaming.
  #
  # Unlike other llm.rb providers which use API key authentication,
  # Bedrock uses AWS Signature V4 (SigV4) for request signing.
  # You must provide AWS credentials (access key, secret key, and region)
  # instead of a single API key.
  #
  # Streaming uses the AWS Event Stream binary protocol instead of
  # standard SSE. The binary framing is decoded inline using only
  # Ruby's stdlib.
  #
  # @example
  #   require "llm"
  #
  #   llm = LLM.bedrock(
  #     access_key_id: ENV["AWS_ACCESS_KEY_ID"],
  #     secret_access_key: ENV["AWS_SECRET_ACCESS_KEY"],
  #     region: "us-east-1"
  #   )
  #   ctx = LLM::Context.new(llm)
  #   ctx.talk "Hello, how are you?"
  #   ctx.messages.select(&:assistant?).each { puts _1.content }
  class Bedrock < Provider
    require_relative "bedrock/signature"
    require_relative "bedrock/error_handler"
    require_relative "bedrock/request_adapter"
    require_relative "bedrock/response_adapter"
    require_relative "bedrock/stream_decoder"
    require_relative "bedrock/stream_parser"

    include RequestAdapter

    HOST_PATTERN = "bedrock-runtime.%s.amazonaws.com"

    ##
    # @param access_key_id [String] AWS access key ID
    # @param secret_access_key [String] AWS secret access key
    # @param region [String] AWS region (e.g. "us-east-1")
    # @param session_token [String, nil] AWS session token for temporary credentials
    # @param host [String, nil] Override the Bedrock API host
    # @param port [Integer] Connection port
    # @param ssl [Boolean] Whether to use SSL
    # @param timeout [Integer] Request timeout in seconds
    def initialize(access_key_id: nil, secret_access_key: nil,
                   region: nil, session_token: nil,
                   host: nil, port: 443, ssl: true, timeout: 60,
                   **)
      @access_key_id = access_key_id
      @secret_access_key = secret_access_key
      @aws_region = region
      @session_token = session_token
      host ||= HOST_PATTERN % region if region
      host ||= HOST_PATTERN % "us-east-1"
      @aws_host = host
      super(key: @access_key_id, host:, port:, ssl:, timeout:, persistent: false)
    end

    ##
    # @return [Symbol] Returns the provider's name
    def name
      :bedrock
    end

    ##
    # Provides an interface to the Bedrock Converse API
    #
    # @see https://docs.aws.amazon.com/bedrock/latest/APIReference/API_runtime_Converse.html
    #
    # @param prompt (see LLM::Provider#complete)
    # @param params (see LLM::Provider#complete)
    # @return (see LLM::Provider#complete)
    def complete(prompt, params = {})
      params, stream, tools, role = normalize_complete_params(params)
      req, messages, body = build_complete_request(prompt, params, role, stream:)
      tracer.set_request_metadata(user_input: extract_user_input(messages, fallback: prompt))
      signed_headers = Signature.new(
        access_key_id: @access_key_id,
        secret_access_key: @secret_access_key,
        region: @aws_region,
        method: req.method,
        path: req.path,
        body:,
        host: @aws_host,
        session_token: @session_token
      ).to_h
      signed_headers.each { |k, v| req[k] = v }
      model_id = model_id_for(req.path)
      res, span, tracer = execute(request: req, stream:, operation: "chat", stream_parser:, model: model_id)
      res = ResponseAdapter.adapt(res, type: :completion)
        .extend(Module.new { define_method(:__tools__) { tools } })
      tracer.on_request_finish(operation: "chat", model: model_id, res:, span:)
      res
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
    # @raise [NotImplementedError]
    def embed(input, model: nil, **params)
      raise NotImplementedError
    end

    ##
    # @return [String]
    def assistant_role
      "assistant"
    end

    ##
    # Bedrock expects tool results as user messages containing
    # `toolResult` content blocks rather than a distinct `tool` role.
    # @return (see LLM::Provider#tool_role)
    def tool_role
      :user
    end

    ##
    # @return [String]
    def default_model
      "deepseek.v3.2"
    end

    private

    def headers
      lock do
        (@headers || {}).merge("Content-Type" => "application/json")
      end
    end

    def stream_parser
      LLM::Bedrock::StreamParser
    end

    def error_handler
      LLM::Bedrock::ErrorHandler
    end

    def stream_decoder
      LLM::Bedrock::StreamDecoder
    end

    def normalize_complete_params(params)
      params = {role: :user, model: default_model, max_tokens: 2048}.merge!(params)
      tools = resolve_tools(params.delete(:tools))
      params = [params, adapt_schema(params), adapt_tools(tools)].inject({}, &:merge!).compact
      role, stream = params.delete(:role), params.delete(:stream)
      params[:stream] = true if streamable?(stream) || stream == true
      [params, stream, tools, role]
    end

    def build_complete_request(prompt, params, role, stream: nil)
      messages = build_complete_messages(prompt, params, role)
      model_id = params.delete(:model) || default_model
      payload = build_converse_payload(messages, params)
      body = LLM.json.dump(payload)
      path = stream ? "/model/#{model_id}/converse-stream" \
                    : "/model/#{model_id}/converse"
      req = Net::HTTP::Post.new(path, headers)
      set_body_stream(req, StringIO.new(body))
      [req, messages, body]
    end

    def build_complete_messages(prompt, params, role)
      if LLM::Prompt === prompt
        [*(params.delete(:messages) || []), *prompt]
      else
        [*(params.delete(:messages) || []), Message.new(role, prompt)]
      end
    end

    def build_converse_payload(messages, params)
      adapted = adapt(messages)
      payload = {}
      payload[:system] = adapted[:system] if adapted[:system]&.any?
      payload[:messages] = adapted[:messages]
      inference_config = {}
      inference_config[:maxTokens] = params.delete(:max_tokens) if params[:max_tokens]
      inference_config[:temperature] = params.delete(:temperature) if params.key?(:temperature)
      inference_config[:topP] = params.delete(:top_p) if params.key?(:top_p)
      inference_config[:stopSequences] = params.delete(:stop) if params[:stop]
      payload[:inferenceConfig] = inference_config unless inference_config.empty?
      payload[:toolConfig] = params.delete(:toolConfig) if params[:toolConfig]
      payload[:outputConfig] = params.delete(:outputConfig) if params[:outputConfig]
      additional = {}
      top_k = params.delete(:top_k)
      additional[:top_k] = top_k if top_k
      payload[:additionalModelRequestFields] = additional unless additional.empty?
      payload
    end

    def extract_user_input(messages, fallback:)
      message = messages.reverse.find(&:user?) || messages.last
      value = message&.content || fallback
      value.is_a?(String) ? value : LLM.json.dump(value)
    end

    def model_id_for(path)
      path[%r{\A/model/(.+?)/converse(?:-stream)?\z}, 1] || default_model
    end
  end
end
