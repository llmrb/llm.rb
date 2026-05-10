# frozen_string_literal: true

##
# The Provider class represents an abstract class for
# LLM (Language Model) providers.
#
# @abstract
class LLM::Provider
  include LLM::Transport::Execution

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
  # @param [String] base_path
  #  Optional base path prefix for HTTP API routes.
  # @param [Boolean] persistent
  #  Whether to use a persistent connection.
  #  Requires the net-http-persistent gem.
  # @param [LLM::Transport, Class, nil] transport
  #  Optional override with any {LLM::Transport} instance or subclass.
  def initialize(key:, host:, port: 443, timeout: 60, ssl: true, base_path: "", persistent: false, transport: nil)
    @key = key
    @host = host
    @port = port
    @timeout = timeout
    @ssl = ssl
    @base_path = normalize_base_path(base_path)
    @base_uri = URI("#{ssl ? "https" : "http"}://#{host}:#{port}/")
    @headers = {"User-Agent" => "llm.rb v#{LLM::VERSION}"}
    @transport = resolve_transport(transport, persistent:)
    @monitor = Monitor.new
  end

  ##
  # Returns an inspection of the provider object
  # @return [String]
  # @note The secret key is redacted in inspect for security reasons
  def inspect
    "#<#{self.class.name}:0x#{object_id.to_s(16)} @key=[REDACTED] @transport=#{transport.inspect} @tracer=#{tracer.inspect}>"
  end

  ##
  # @raise [NotImplementedError]
  #  When the method is not implemented by a subclass
  # @return [Symbol]
  #  Returns the provider's name
  def name
    raise NotImplementedError
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
  # @return [LLM::Context]
  def chat(prompt, params = {})
    role = params.delete(:role)
    LLM::Context.new(self, params).talk(prompt, role:)
  end

  ##
  # Starts a new chat powered by the responses API
  # @param prompt (see LLM::Provider#complete)
  # @param params (see LLM::Provider#complete)
  # @raise (see LLM::Provider#complete)
  # @return [LLM::Context]
  def respond(prompt, params = {})
    role = params.delete(:role)
    LLM::Context.new(self, params).respond(prompt, role:)
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
  # @return [LLM::OpenAI::Images, LLM::Google::Images]
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
    LLM::Schema.new
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
    lock do
      tap { @headers.merge!(headers) }
    end
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
  # @return [Symbol]
  def tool_role
    :tool
  end

  ##
  # @return [LLM::Tracer]
  #  Returns the current scoped tracer override or provider default tracer
  def tracer
    weakmap[self] || @tracer || LLM::Tracer::Null.new(self)
  end

  ##
  # Set the provider's default tracer
  # This tracer is shared by the provider instance and becomes the fallback
  # whenever no scoped override is active.
  # @example
  #   llm = LLM.openai(key: ENV["KEY"])
  #   llm.tracer = LLM::Tracer::Logger.new(llm, path: "/path/to/log.txt")
  # @param [LLM::Tracer] tracer
  #  A tracer
  # @return [void]
  def tracer=(tracer)
    @tracer = tracer
  end

  ##
  # Override the tracer for the current fiber while the block runs.
  # This is useful when you want per-request or per-turn tracing without
  # replacing the provider's default tracer.
  # @example
  #   llm.with_tracer(LLM::Tracer::Logger.new(llm, io: $stdout)) do
  #     llm.complete("hello", model: "gpt-5.4-mini")
  #   end
  # @param [LLM::Tracer] tracer
  # @yield
  # @return [Object]
  def with_tracer(tracer)
    had_override = weakmap.key?(self)
    previous = weakmap[self]
    weakmap[self] = tracer
    yield
  ensure
    if had_override
      weakmap[self] = previous
    elsif weakmap.respond_to?(:delete)
      weakmap.delete(self)
    else
      weakmap[self] = nil
    end
  end

  ##
  # Interrupt the active request, if any.
  # @param [Fiber] owner
  # @return [nil]
  def interrupt!(owner)
    transport.interrupt!(owner)
  end
  alias_method :cancel!, :interrupt!

  ##
  # Returns the current request owner used by the transport.
  # @return [Object]
  # @api private
  def request_owner
    transport.request_owner
  end

  ##
  # @param [Object] stream
  # @return [Boolean]
  def streamable?(stream)
    LLM::Stream === stream || stream.respond_to?(:<<)
  end

  private

  def path(suffix)
    return suffix if @base_path.empty?
    "#{@base_path}#{suffix}"
  end

  def normalize_base_path(path)
    path = path.to_s.strip
    return "" if path.empty? || path == "/"
    path = "/#{path}" unless path.start_with?("/")
    path.sub(%r{/+\z}, "")
  end

  attr_reader :base_uri, :host, :port, :timeout, :ssl, :transport

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
  # @return [Class]
  #  Returns the class responsible for decoding streamed response bodies
  def stream_decoder
    LLM::Transport::StreamDecoder
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
  # @api private
  def lock(&)
    @monitor.synchronize(&)
  end

  ##
  # @api private
  def default_transport(persistent:)
    transport_class = persistent ? LLM::Transport::PersistentHTTP : LLM::Transport::HTTP
    transport_class.new(host:, port:, timeout:, ssl:)
  end

  ##
  # @api private
  def resolve_transport(transport, persistent:)
    return default_transport(persistent:) if transport.nil?
    if Class === transport && transport <= LLM::Transport
      return transport.new(host:, port:, timeout:, ssl:)
    end
    transport
  end

  ##
  # @api private
  def thread
    Thread.current
  end

  ##
  # @api private
  def weakmap
    thread[:"llm.provider.weakmap"] ||= ObjectSpace::WeakMap.new
  end
end
