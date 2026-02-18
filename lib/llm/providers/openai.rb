# frozen_string_literal: true

module LLM
  ##
  # The OpenAI class implements a provider for
  # [OpenAI](https://platform.openai.com/).
  #
  # @example
  #   #!/usr/bin/env ruby
  #   require "llm"
  #
  #   llm = LLM.openai(key: ENV["KEY"])
  #   bot = LLM::Bot.new(llm)
  #   bot.chat ["Tell me about this photo", File.open("/images/capybara.jpg", "rb")]
  #   bot.messages.select(&:assistant?).each { print "[#{_1.role}]", _1.content, "\n" }
  class OpenAI < Provider
    require_relative "openai/error_handler"
    require_relative "openai/request_adapter"
    require_relative "openai/response_adapter"
    require_relative "openai/stream_parser"
    require_relative "openai/models"
    require_relative "openai/responses"
    require_relative "openai/images"
    require_relative "openai/audio"
    require_relative "openai/files"
    require_relative "openai/moderations"
    require_relative "openai/vector_stores"

    include RequestAdapter

    HOST = "api.openai.com"

    ##
    # @param key (see LLM::Provider#initialize)
    def initialize(**)
      super(host: HOST, **)
    end

    ##
    # Provides an embedding
    # @see https://platform.openai.com/docs/api-reference/embeddings/create OpenAI docs
    # @param input (see LLM::Provider#embed)
    # @param model (see LLM::Provider#embed)
    # @param params (see LLM::Provider#embed)
    # @raise (see LLM::Provider#request)
    # @return (see LLM::Provider#embed)
    def embed(input, model: "text-embedding-3-small", **params)
      req = Net::HTTP::Post.new("/v1/embeddings", headers)
      req.body = LLM.json.dump({input:, model:}.merge!(params))
      res, span = execute(request: req, operation: "embeddings", model:)
      res = ResponseAdapter.adapt(res, type: :embedding)
      finish_trace(operation: "embeddings", model:, res:, span:)
    end

    ##
    # Provides an interface to the chat completions API
    # @see https://platform.openai.com/docs/api-reference/chat/create OpenAI docs
    # @param prompt (see LLM::Provider#complete)
    # @param params (see LLM::Provider#complete)
    # @example (see LLM::Provider#complete)
    # @raise (see LLM::Provider#request)
    # @raise [LLM::PromptError]
    #  When given an object a provider does not understand
    # @return (see LLM::Provider#complete)
    def complete(prompt, params = {})
      params, stream, tools, role = normalize_complete_params(params)
      req = build_complete_request(prompt, params, role)
      res, span = execute(request: req, stream: stream, operation: "chat", model: params[:model])
      res = ResponseAdapter.adapt(res, type: :completion)
        .extend(Module.new { define_method(:__tools__) { tools } })
      finish_trace(operation: "chat", model: params[:model], res:, span:)
    end

    ##
    # Provides an interface to OpenAI's response API
    # @see https://platform.openai.com/docs/api-reference/responses/create OpenAI docs
    # @return [LLM::OpenAI::Responses]
    def responses
      LLM::OpenAI::Responses.new(self)
    end

    ##
    # Provides an interface to OpenAI's image generation API
    # @see https://platform.openai.com/docs/api-reference/images/create OpenAI docs
    # @return [LLM::OpenAI::Images]
    def images
      LLM::OpenAI::Images.new(self)
    end

    ##
    # Provides an interface to OpenAI's audio generation API
    # @see https://platform.openai.com/docs/api-reference/audio/createSpeech OpenAI docs
    # @return [LLM::OpenAI::Audio]
    def audio
      LLM::OpenAI::Audio.new(self)
    end

    ##
    # Provides an interface to OpenAI's files API
    # @see https://platform.openai.com/docs/api-reference/files/create OpenAI docs
    # @return [LLM::OpenAI::Files]
    def files
      LLM::OpenAI::Files.new(self)
    end

    ##
    # Provides an interface to OpenAI's models API
    # @see https://platform.openai.com/docs/api-reference/models/list OpenAI docs
    # @return [LLM::OpenAI::Models]
    def models
      LLM::OpenAI::Models.new(self)
    end

    ##
    # Provides an interface to OpenAI's moderation API
    # @see https://platform.openai.com/docs/api-reference/moderations/create OpenAI docs
    # @see https://platform.openai.com/docs/models#moderation OpenAI moderation models
    # @return [LLM::OpenAI::Moderations]
    def moderations
      LLM::OpenAI::Moderations.new(self)
    end

    ##
    # Provides an interface to OpenAI's vector store API
    # @see https://platform.openai.com/docs/api-reference/vector-stores/create OpenAI docs
    # @return [LLM::OpenAI::VectorStore]
    def vector_stores
      LLM::OpenAI::VectorStores.new(self)
    end

    ##
    # @return (see LLM::Provider#assistant_role)
    def assistant_role
      "assistant"
    end

    ##
    # Returns the default model for chat completions
    # @see https://platform.openai.com/docs/models/gpt-4.1 gpt-4.1
    # @return [String]
    def default_model
      "gpt-4.1"
    end

    ##
    # @note
    #  This method includes certain tools that require configuration
    #  through a set of options that are easier to set through the
    #  {LLM::Provider#server_tool LLM::Provider#server_tool} method.
    # @return (see LLM::Provider#server_tools)
    def server_tools
      {
        web_search: server_tool(:web_search),
        file_search: server_tool(:file_search),
        image_generation: server_tool(:image_generation),
        code_interpreter: server_tool(:code_interpreter),
        computer_use: server_tool(:computer_use)
      }
    end

    ##
    # A convenience method for performing a web search using the
    # OpenAI web search tool.
    # @example
    #   llm = LLM.openai(key: ENV["KEY"])
    #   res = llm.web_search(query: "summarize today's news")
    #   res.search_results.each { |item| print item.title, ": ", item.url, "\n" }
    # @param query [String] The search query.
    # @return [LLM::Response] The response from the LLM provider.
    def web_search(query:)
      ResponseAdapter.adapt(
        responses.create(query, store: false, tools: [server_tools[:web_search]]),
        type: :web_search
      )
    end

    private

    def completions_path
      "/v1/chat/completions"
    end

    def headers
      (@headers || {}).merge(
        "Content-Type" => "application/json",
        "Authorization" => "Bearer #{@key}"
      )
    end

    def stream_parser
      LLM::OpenAI::StreamParser
    end

    def error_handler
      LLM::OpenAI::ErrorHandler
    end

    def normalize_complete_params(params)
      params = {role: :user, model: default_model}.merge!(params)
      tools = resolve_tools(params.delete(:tools))
      params = [params, adapt_schema(params), adapt_tools(tools)].inject({}, &:merge!).compact
      role, stream = params.delete(:role), params.delete(:stream)
      params[:stream] = true if stream.respond_to?(:<<) || stream == true
      if params[:stream]
        params[:stream_options] = {include_usage: true}.merge!(params[:stream_options] || {})
      end
      [params, stream, tools, role]
    end

    def build_complete_request(prompt, params, role)
      messages = [*(params.delete(:messages) || []), Message.new(role, prompt)]
      body = LLM.json.dump({messages: adapt(messages, mode: :complete).flatten}.merge!(params))
      req = Net::HTTP::Post.new(completions_path, headers)
      set_body_stream(req, StringIO.new(body))
      req
    end
  end
end
