# frozen_string_literal: true

##
# The Provider class represents an abstract class for
# LLM (Language Model) providers.
#
# @abstract
class LLM::Provider
  require "net/http"
  require_relative "client"
  include LLM::Client

  @@clients = {}

  ##
  # @api private
  def self.clients = @@clients

  ##
  # @param [String, nil] key
  #  The secret key for authentication
  # @param [String] host
  #  The host address of the LLM provider
  # @param [Integer] port
  #  The port number
  # @param [Integer] timeout
  #  The number of seconds to wait for a response
  # @param [Boolean] ssl
  #  Whether to use SSL for the connection
  # @param [Boolean] persistent
  #  Whether to use a persistent connection.
  #  Requires the net-http-persistent gem.
  def initialize(key:, host:, port: 443, timeout: 60, ssl: true, persistent: false)
    @key = key
    @host = host
    @port = port
    @timeout = timeout
    @ssl = ssl
    @client = persistent ? persistent_client : transient_client
    @tracer = LLM::Tracer::Null.new(self)
    @base_uri = URI("#{ssl ? "https" : "http"}://#{host}:#{port}/")
  end

  ##
  # Returns an inspection of the provider object
  # @return [String]
  # @note The secret key is redacted in inspect for security reasons
  def inspect
    "#<#{self.class.name}:0x#{object_id.to_s(16)} @key=[REDACTED] @client=#{@client.inspect} @tracer=#{@tracer.inspect}>"
  end

  ##
  # Provides an embedding
  # @param [String, Array<String>] input
  #  The input to embed
  # @param [String] model
  #  The embedding model to use
  # @param [Hash] params
  #  Other embedding parameters
  # @raise [NotImplementedError]
  #  When the method is not implemented by a subclass
  # @return [LLM::Response]
  def embed(input, model: nil, **params)
    raise NotImplementedError
  end

  ##
  # Provides an interface to the chat completions API
  # @example
  #   llm = LLM.openai(key: ENV["KEY"])
  #   messages = [{role: "system", content: "Your task is to answer all of my questions"}]
  #   res = llm.complete("5 + 2 ?", messages:)
  #   print "[#{res.messages[0].role}]", res.messages[0].content, "\n"
  # @param [String] prompt
  #  The input prompt to be completed
  # @param [Hash] params
  #  The parameters to maintain throughout the conversation.
  #  Any parameter the provider supports can be included and
  #  not only those listed here.
  # @option params [Symbol] :role Defaults to the provider's default role
  # @option params [String] :model Defaults to the provider's default model
  # @option params [#to_json, nil] :schema Defaults to nil
  # @option params [Array<LLM::Function>, nil] :tools Defaults to nil
  # @raise [NotImplementedError]
  #  When the method is not implemented by a subclass
  # @return [LLM::Response]
  def complete(prompt, params = {})
    raise NotImplementedError
  end

  ##
  # Starts a new chat powered by the chat completions API
  # @param prompt (see LLM::Provider#complete)
  # @param params (see LLM::Provider#complete)
  # @return [LLM::Bot]
  def chat(prompt, params = {})
    role = params.delete(:role)
    LLM::Bot.new(self, params).chat(prompt, role:)
  end

  ##
  # Starts a new chat powered by the responses API
  # @param prompt (see LLM::Provider#complete)
  # @param params (see LLM::Provider#complete)
  # @raise (see LLM::Provider#complete)
  # @return [LLM::Bot]
  def respond(prompt, params = {})
    role = params.delete(:role)
    LLM::Bot.new(self, params).respond(prompt, role:)
  end

  ##
  # @note
  # Compared to the chat completions API, the responses API
  # can require less bandwidth on each turn, maintain state
  # server-side, and produce faster responses.
  # @return [LLM::OpenAI::Responses]
  #  Returns an interface to the responses API
  def responses
    raise NotImplementedError
  end

  ##
  # @return [LLM::OpenAI::Images, LLM::Gemini::Images]
  #  Returns an interface to the images API
  def images
    raise NotImplementedError
  end

  ##
  # @return [LLM::OpenAI::Audio]
  #  Returns an interface to the audio API
  def audio
    raise NotImplementedError
  end

  ##
  # @return [LLM::OpenAI::Files]
  #  Returns an interface to the files API
  def files
    raise NotImplementedError
  end

  ##
  # @return [LLM::OpenAI::Models]
  #  Returns an interface to the models API
  def models
    raise NotImplementedError
  end

  ##
  # @return [LLM::OpenAI::Moderations]
  #  Returns an interface to the moderations API
  def moderations
    raise NotImplementedError
  end

  ##
  # @return [LLM::OpenAI::VectorStore]
  #  Returns an interface to the vector stores API
  def vector_stores
    raise NotImplementedError
  end

  ##
  # @return [String]
  #  Returns the role of the assistant in the conversation.
  #  Usually "assistant" or "model"
  def assistant_role
    raise NotImplementedError
  end

  ##
  # @return [String]
  #  Returns the default model for chat completions
  def default_model
    raise NotImplementedError
  end

  ##
  # Returns an object that can generate a JSON schema
  # @return [LLM::Schema]
  def schema
    @schema ||= LLM::Schema.new
  end

  ##
  # Add one or more headers to all requests
  # @example
  #   llm = LLM.openai(key: ENV["KEY"])
  #   llm.with(headers: {"OpenAI-Organization" => ENV["ORG"]})
  #   llm.with(headers: {"OpenAI-Project" => ENV["PROJECT"]})
  # @param [Hash<String,String>] headers
  #  One or more headers
  # @return [LLM::Provider]
  #  Returns self
  def with(headers:)
    tap { (@headers ||= {}).merge!(headers) }
  end

  ##
  # @note
  #  This method might be outdated, and the {LLM::Provider#server_tool LLM::Provider#server_tool}
  #  method can be used if a tool is not found here.
  # Returns all known tools provided by a provider.
  # @return [String => LLM::ServerTool]
  def server_tools
    {}
  end

  ##
  # @note
  #   OpenAI, Anthropic, and Gemini provide platform-tools for things
  #   like web search, and more.
  # Returns a tool provided by a provider.
  # @example
  #   llm   = LLM.openai(key: ENV["KEY"])
  #   tools = [llm.server_tool(:web_search)]
  #   res   = llm.responses.create("Summarize today's news", tools:)
  #   print res.output_text, "\n"
  # @param [String, Symbol] name The name of the tool
  # @param [Hash] options Configuration options for the tool
  # @return [LLM::ServerTool]
  def server_tool(name, options = {})
    LLM::ServerTool.new(name, options, self)
  end

  ##
  # Provides a web search capability
  # @param [String] query The search query
  # @raise [NotImplementedError]
  #  When the method is not implemented by a subclass
  # @return [LLM::Response]
  def web_search(query:)
    raise NotImplementedError
  end

  ##
  # @return [Symbol]
  def user_role
    :user
  end

  ##
  # @return [Symbol]
  def system_role
    :system
  end

  ##
  # @return [Symbol]
  def developer_role
    :developer
  end

  ##
  # @return [LLM::Tracer]
  #  Returns an LLM tracer
  def tracer
    @tracer
  end

  ##
  # Set the tracer
  # @example
  #   llm = LLM.openai(key: ENV["KEY"])
  #   llm.tracer = LLM::Tracer::Logger.new(llm, file: "/path/to/log.txt")
  #   # ...
  # @param [LLM::Tracer] tracer
  #  A tracer
  # @return [void]
  def tracer=(tracer)
    @tracer = if tracer.nil?
      LLM::Tracer::Null.new(self)
    else
      tracer
    end
  end

  private

  attr_reader :client, :base_uri, :host, :port, :timeout, :ssl

  ##
  # The headers to include with a request
  # @raise [NotImplementedError]
  #  (see LLM::Provider#complete)
  def headers
    raise NotImplementedError
  end

  ##
  # @return [Class]
  #  Returns the class responsible for handling an unsuccessful LLM response
  # @raise [NotImplementedError]
  #  (see LLM::Provider#complete)
  def error_handler
    raise NotImplementedError
  end

  ##
  # @return [Class]
  def event_handler
    LLM::EventHandler
  end

  ##
  # @return [Class]
  #  Returns the provider-specific Server-Side Events (SSE) parser
  def stream_parser
    raise NotImplementedError
  end

  ##
  # Executes a HTTP request
  # @param [Net::HTTPRequest] request
  #  The request to send
  # @param [Proc] b
  #  A block to yield the response to (optional)
  # @return [Net::HTTPResponse]
  #  The response from the server
  # @raise [LLM::Error::Unauthorized]
  #  When authentication fails
  # @raise [LLM::Error::RateLimit]
  #  When the rate limit is exceeded
  # @raise [LLM::Error]
  #  When any other unsuccessful status code is returned
  # @raise [SystemCallError]
  #  When there is a network error at the operating system level
  # @return [Net::HTTPResponse]
  def execute(request:, operation:, stream: nil, stream_parser: self.stream_parser, model: nil, &b)
    span = @tracer.on_request_start(operation:, model:)
    args = (Net::HTTP === client) ? [request] : [URI.join(base_uri, request.path), request]
    res = if stream
      client.request(*args) do |res|
        handler = event_handler.new stream_parser.new(stream)
        parser = LLM::EventStream::Parser.new
        parser.register(handler)
        res.read_body(parser)
        # If the handler body is empty, it means the
        # response was most likely not streamed or
        # parsing has failed. In that case, we fallback
        # on the original response body.
        res.body = LLM::Object.from(handler.body.empty? ? parser.body : handler.body)
      ensure
        parser&.free
      end
    else
      b ? client.request(*args) { (Net::HTTPSuccess === _1) ? b.call(_1) : _1 } :
          client.request(*args)
    end
    [handle_response(res, span), span]
  end

  ##
  # Handles the response from a request
  # @param [Net::HTTPResponse] res
  #  The response to handle
  # @param [Object, nil] span
  #  The span
  # @return [Net::HTTPResponse]
  def handle_response(res, span)
    case res
    when Net::HTTPOK then res.body = parse_response(res)
    else error_handler.new(@tracer, span, res).raise_error!
    end
    res
  end

  def parse_response(res)
    case res["content-type"]
    when %r|\Aapplication/json\s*| then LLM::Object.from(LLM.json.load(res.body))
    else res.body
    end
  end

  ##
  # @param [Net::HTTPRequest] req
  #  The request to set the body stream for
  # @param [IO] io
  #  The IO object to set as the body stream
  # @return [void]
  def set_body_stream(req, io)
    req.body_stream = io
    req["transfer-encoding"] = "chunked" unless req["content-length"]
  end

  ##
  # Resolves tools to their function representations
  # @param [Array<LLM::Function, LLM::Tool>] tools
  #  The tools to map
  # @raise [TypeError]
  #  When a tool is not recognized
  # @return [Array<LLM::Function>]
  def resolve_tools(tools)
    (tools || []).map do |tool|
      if tool.respond_to?(:function)
        tool.function
      elsif [LLM::Function, LLM::ServerTool, Hash].any? { _1 === tool }
        tool
      else
        raise TypeError, "#{tool.class} given as a tool but it is not recognized"
      end
    end
  end

  ##
  # @return [Hash<Symbol, LLM::Tracer>]
  def tracers
    self.class.tracers
  end

  ##
  # Finalizes tracing after a response has been adapted/wrapped.
  # @param [String] operation
  # @param [String, nil] model
  # @param [LLM::Response] res
  # @param [Object, nil] span
  # @return [LLM::Response]
  def finish_trace(operation:, res:, model: nil, span: nil)
    @tracer.on_request_finish(operation:, model:, res:, span:)
    res
  end
end
