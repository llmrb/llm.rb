# frozen_string_literal: true

module LLM::MCP::Transport
  ##
  # The {LLM::MCP::Transport::HTTP LLM::MCP::Transport::HTTP} class
  # provides an HTTP transport for {LLM::MCP LLM::MCP}. It sends
  # JSON-RPC messages with HTTP POST requests and buffers response
  # messages for non-blocking reads.
  class HTTP
    require_relative "http/event_handler"

    ##
    # @param [String] url
    #  The URL for the MCP HTTP endpoint
    # @param [Hash] headers
    #  Extra headers to send with requests
    # @param [Integer, nil] timeout
    #  The timeout in seconds. Defaults to nil
    # @param [LLM::Transport, Class, nil] transport
    #  Optional override with any {LLM::Transport} instance or subclass
    # @return [LLM::MCP::Transport::HTTP]
    def initialize(url:, headers: {}, timeout: nil, transport: nil)
      @uri = URI.parse(url)
      @headers = headers
      @transport = resolve_transport(transport, timeout:)
      @queue = []
      @monitor = Monitor.new
      @running = false
    end

    ##
    # Starts the HTTP transport.
    # @raise [LLM::MCP::Error]
    #  When the transport is already running
    # @return [void]
    def start
      lock do
        raise LLM::MCP::Error, "MCP transport is already running" if running?
        @queue.clear
        @running = true
      end
    end

    ##
    # Stops the HTTP transport and closes the connection.
    # This method is idempotent.
    # @return [void]
    def stop
      lock do
        return nil unless running?
        @running = false
        nil
      end
    end

    ##
    # Writes a JSON-RPC message via HTTP POST.
    # @param [Hash] message
    #  The JSON-RPC message
    # @raise [LLM::MCP::Error]
    #  When the transport is not running or the HTTP request fails
    # @return [void]
    def write(message)
      raise LLM::MCP::Error, "MCP transport is not running" unless running?
      req = Net::HTTP::Post.new(uri.request_uri, headers.merge("content-type" => "application/json"))
      req.body = LLM.json.dump(message)
      res = transport.request(req, owner: self) { consume(_1) }
      res = LLM::Transport::Response.from(res)
      raise LLM::MCP::Error, "MCP transport write failed with HTTP #{res.code}" unless res.success?
    end

    ##
    # Reads the next queued message without blocking.
    # @raise [LLM::MCP::Error]
    #  When the transport is not running
    # @raise [IO::EAGAINWaitReadable]
    #  When no complete message is available to read
    # @return [Hash]
    def read_nonblock
      lock do
        raise LLM::MCP::Error, "MCP transport is not running" unless running?
        raise IO::EAGAINWaitReadable, "no complete message available" if @queue.empty?
        @queue.shift
      end
    end

    ##
    # @return [Boolean]
    #  Returns true when the MCP server connection is alive
    def running?
      @running
    end

    private

    attr_reader :uri, :headers, :transport

    def consume(res)
      res = LLM::Transport::Response.from(res)
      read(res)
      res
    end

    def resolve_transport(transport, timeout:)
      return default_transport(timeout:) if transport.nil?
      if Class === transport && transport <= LLM::Transport
        return transport.new(host: uri.host, port: uri.port, timeout:, ssl: uri.scheme == "https")
      end
      transport
    end

    def default_transport(timeout:)
      LLM::Transport::HTTP.new(host: uri.host, port: uri.port, timeout:, ssl: uri.scheme == "https")
    end

    def read(res)
      if res["content-type"].to_s.include?("text/event-stream")
        parser = LLM::EventStream::Parser.new
        parser.register EventHandler.new { enqueue(_1) }
        res.read_body { parser << _1 }
        parser.free
      else
        body = +""
        res.read_body { body << _1 }
        enqueue(LLM.json.load(body)) unless body.empty?
      end
    end

    def enqueue(message)
      lock { @queue << message }
    end

    def lock(&)
      @monitor.synchronize(&)
    end
  end
end
