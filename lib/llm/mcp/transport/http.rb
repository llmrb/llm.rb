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
    # @return [LLM::MCP::Transport::HTTP]
    def initialize(url:, headers: {}, timeout: nil)
      @uri = URI.parse(url)
      @use_ssl = @uri.scheme == "https"
      @headers = headers
      @timeout = timeout
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
      req = Net::HTTP::Post.new(uri.path, headers.merge("content-type" => "application/json"))
      req.body = LLM.json.dump(message)
      if persistent_client.nil?
        http = Net::HTTP.start(uri.host, uri.port, use_ssl:, open_timeout: timeout, read_timeout: timeout)
        args = [req]
      else
        http = persistent_client
        args = [uri, req]
      end
      http.request(*args) do |res|
        unless Net::HTTPSuccess === res
          raise LLM::MCP::Error, "MCP transport write failed with HTTP #{res.code}"
        end
        read(res)
      end
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

    attr_reader :uri, :use_ssl, :headers, :timeout

    def setup_persistent_client!
      LLM.lock(:mcp) do
        LLM.require "net/http/persistent" unless defined?(Net::HTTP::Persistent)
        unless LLM::MCP.clients.key?(key)
          http = Net::HTTP::Persistent.new(name: self.class.name)
          http.read_timeout = timeout
          http.open_timeout = timeout
          LLM::MCP.clients[key] ||= http
        end
      end
      self
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

    def persistent_client
      LLM::MCP.clients[key]
    end

    def key
      "#{uri.scheme}:#{uri.host}:#{uri.port}:#{timeout}"
    end

    def lock(&)
      @monitor.synchronize(&)
    end
  end
end
