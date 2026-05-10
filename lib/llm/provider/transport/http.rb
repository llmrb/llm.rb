# frozen_string_literal: true

class LLM::Provider
  class Transport
    ##
    # The {LLM::Provider::Transport::HTTP LLM::Provider::Transport::HTTP}
    # transport manages HTTP connections for {LLM::Provider}. It handles
    # transient and persistent clients, tracks active requests by owner,
    # and interrupts in-flight requests when needed.
    #
    # @api private
    class HTTP < LLM::Provider::Transport
      require_relative "http/stream_decoder"
      require_relative "http/interruptible"

      include Interruptible

      ##
      # @param [String] host
      # @param [Integer] port
      # @param [Integer] timeout
      # @param [Boolean] ssl
      # @param [Boolean] persistent
      # @return [LLM::Provider::Transport::HTTP]
      def initialize(host:, port:, timeout:, ssl:, persistent: false)
        @host = host
        @port = port
        @timeout = timeout
        @ssl = ssl
        @base_uri = URI("#{ssl ? "https" : "http"}://#{host}:#{port}/")
        @persistent_client = persistent ? persistent_client : nil
        @monitor = Monitor.new
      end

      ##
      # Interrupt an active request, if any.
      # @param [Fiber] owner
      # @return [nil]
      def interrupt!(owner)
        super
      end

      ##
      # Returns whether an execution owner was interrupted.
      # @param [Fiber] owner
      # @return [Boolean, nil]
      def interrupted?(owner)
        super
      end

      ##
      # Returns the current request owner.
      # @return [Object]
      def request_owner
        return Fiber.current unless defined?(::Async)
        Async::Task.current? ? Async::Task.current : Fiber.current
      end

      ##
      # Configures the transport to use a persistent HTTP connection pool.
      # @return [LLM::Provider::Transport::HTTP]
      def persist!
        client = persistent_client
        lock do
          @persistent_client = client
          self
        end
      end
      alias_method :persistent, :persist!

      ##
      # @return [Boolean]
      def persistent?
        !@persistent_client.nil?
      end

      ##
      # Performs a request on the current HTTP transport.
      # @param [Net::HTTPRequest] request
      # @param [Fiber] owner
      # @yieldparam [Net::HTTP] http
      # @return [Object]
      def request(request, owner:, &)
        if persistent?
          request_persistent(request, owner, &)
        else
          request_transient(request, owner, &)
        end
      ensure
        clear_request(owner)
      end

      ##
      # @return [String]
      def inspect
        "#<#{self.class.name}:0x#{object_id.to_s(16)} @persistent=#{persistent?}>"
      end

      private

      attr_reader :host, :port, :timeout, :ssl, :base_uri

      def request_transient(request, owner, &)
        http = transient_client
        set_request(Request.new(http:), owner)
        yield http
      end

      def request_persistent(request, owner, &)
        persistent_client.connection_for(URI.join(base_uri, request.path)) do |connection|
          set_request(Request.new(http: persistent_client, connection:), owner)
          yield connection.http
        end
      end

      def persistent_client
        LLM.lock(:clients) do
          if LLM.clients[client_id]
            LLM.clients[client_id]
          else
            require "net/http/persistent" unless defined?(Net::HTTP::Persistent)
            client = Net::HTTP::Persistent.new(name: self.class.name)
            client.read_timeout = timeout
            LLM.clients[client_id] = client
          end
        end
      end

      def transient_client
        client = Net::HTTP.new(host, port)
        client.read_timeout = timeout
        client.use_ssl = ssl
        client
      end

      def client_id
        "#{host}:#{port}:#{timeout}:#{ssl}"
      end

      def lock(&)
        @monitor.synchronize(&)
      end
    end
  end
end
