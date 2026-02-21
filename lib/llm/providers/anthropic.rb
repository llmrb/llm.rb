# frozen_string_literal: true

module LLM
  ##
  # The Anthropic class implements a provider for
  # [Anthropic](https://www.anthropic.com).
  #
  # @example
  #   #!/usr/bin/env ruby
  #   require "llm"
  #
  #   llm = LLM.anthropic(key: ENV["KEY"])
  #   ses = LLM::Session.new(llm)
  #   ses.talk ["Tell me about this photo", ses.local_file("/images/photo.png")]
  #   ses.messages.select(&:assistant?).each { print "[#{_1.role}]", _1.content, "\n" }
  class Anthropic < Provider
    require_relative "anthropic/error_handler"
    require_relative "anthropic/request_adapter"
    require_relative "anthropic/response_adapter"
    require_relative "anthropic/stream_parser"
    require_relative "anthropic/models"
    require_relative "anthropic/files"
    include RequestAdapter

    HOST = "api.anthropic.com"

    ##
    # @param key (see LLM::Provider#initialize)
    def initialize(**)
      super(host: HOST, **)
    end

    ##
    # Provides an interface to the chat completions API
    # @see https://docs.anthropic.com/en/api/messages Anthropic docs
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
    # Provides an interface to Anthropic's models API
    # @see https://docs.anthropic.com/en/api/models-list
    # @return [LLM::Anthropic::Models]
    def models
      LLM::Anthropic::Models.new(self)
    end

    ##
    # Provides an interface to Anthropic's files API
    # @see https://docs.anthropic.com/en/docs/build-with-claude/files Anthropic docs
    # @return [LLM::Anthropic::Files]
    def files
      LLM::Anthropic::Files.new(self)
    end

    ##
    # @return (see LLM::Provider#assistant_role)
    def assistant_role
      "assistant"
    end

    ##
    # Returns the default model for chat completions
    # @see https://docs.anthropic.com/en/docs/about-claude/models/all-models#model-comparison-table claude-sonnet-4-20250514
    # @return [String]
    def default_model
      "claude-sonnet-4-20250514"
    end

    ##
    # @note
    #  This method includes certain tools that require configuration
    #  through a set of options that are easier to set through the
    #  {LLM::Provider#server_tool LLM::Provider#server_tool} method.
    # @see https://docs.anthropic.com/en/docs/agents-and-tools/tool-use/web-search-tool Anthropic docs
    # @return (see LLM::Provider#server_tools)
    def server_tools
      {
        bash: server_tool(:bash, type: "bash_20250124"),
        web_search: server_tool(:web_search, type: "web_search_20250305", max_uses: 5),
        text_editor: server_tool(:str_replace_based_edit_tool, type: "text_editor_20250728", max_characters: 10_000)
      }
    end

    ##
    # A convenience method for performing a web search using the
    # Anthropic web search tool.
    # @example
    #   llm = LLM.anthropic(key: ENV["KEY"])
    #   res = llm.web_search(query: "summarize today's news")
    #   res.search_results.each { |item| print item.title, ": ", item.url, "\n" }
    # @param query [String] The search query.
    # @return [LLM::Response] The response from the LLM provider.
    def web_search(query:)
      ResponseAdapter.adapt(complete(query, tools: [server_tools[:web_search]]), type: :web_search)
    end

    private

    def headers
      (@headers || {}).merge(
        "Content-Type" => "application/json",
        "x-api-key" => @key,
        "anthropic-version" => "2023-06-01",
        "anthropic-beta" => "files-api-2025-04-14"
      )
    end

    def stream_parser
      LLM::Anthropic::StreamParser
    end

    def error_handler
      LLM::Anthropic::ErrorHandler
    end

    def normalize_complete_params(params)
      params = {role: :user, model: default_model, max_tokens: 1024}.merge!(params)
      tools = resolve_tools(params.delete(:tools))
      params = [params, adapt_tools(tools)].inject({}, &:merge!).compact
      role, stream = params.delete(:role), params.delete(:stream)
      params[:stream] = true if stream.respond_to?(:<<) || stream == true
      [params, stream, tools, role]
    end

    def build_complete_request(prompt, params, role)
      messages = [*(params.delete(:messages) || []), Message.new(role, prompt)]
      body = LLM.json.dump({messages: [adapt(messages)].flatten}.merge!(params))
      req = Net::HTTP::Post.new("/v1/messages", headers)
      set_body_stream(req, StringIO.new(body))
      req
    end
  end
end
