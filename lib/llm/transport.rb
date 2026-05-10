# frozen_string_literal: true

module LLM
  ##
  # The {LLM::Transport LLM::Transport} class defines the execution
  # interface used by {LLM::Provider}.
  #
  # Custom transports can subclass this class and override {#request} to
  # execute provider requests without changing request adapters or
  # response adapters.
  #
  # Only {#request} is required. The remaining methods are optional hooks
  # for features such as interruption, request ownership, or persistence,
  # and only need to be implemented when the underlying adapter can
  # support them.
  #
  # Returned responses should implement the
  # {LLM::Transport::Response LLM::Transport::Response} interface. In
  # practice this can mean adapting another client's response object so
  # existing provider execution, response adapters, and error handlers
  # can rely on one normalized response contract instead of
  # transport-specific classes.
  class Transport
    require_relative "transport/response"
    require_relative "transport/stream_decoder"
    require_relative "transport/http"
    require_relative "transport/persistent_http"
    require_relative "transport/execution"

    ##
    # Returns the built-in Net::HTTP transport class.
    # @return [Class]
    def self.net_http
      HTTP
    end

    ##
    # Returns the built-in Net::HTTP::Persistent transport class.
    # @return [Class]
    def self.net_http_persistent
      PersistentHTTP
    end

    ##
    # Performs a request through the transport.
    # @param [Net::HTTPRequest] request
    # @param [Object] owner
    # @param [LLM::Object, nil] stream
    # @yieldparam [LLM::Transport::Response] response
    # @return [Object]
    def request(request, owner:, stream: nil, &)
      raise NotImplementedError
    end

    ##
    # Returns the current request owner.
    # @return [Object]
    def request_owner
      return Fiber.current unless defined?(::Async)
      Async::Task.current? ? Async::Task.current : Fiber.current
    end

    ##
    # Returns the exception classes that indicate an interrupted request.
    # @return [Array<Class<Exception>>]
    def interrupt_errors
      []
    end

    ##
    # Interrupt an active request, if any.
    # @param [Object] owner
    # @return [nil]
    def interrupt!(owner)
      raise NotImplementedError
    end

    ##
    # Returns whether an execution owner was interrupted.
    # @param [Object] owner
    # @return [Boolean, nil]
    def interrupted?(owner)
      nil
    end

    private

    ##
    # @api private
    # @note
    #  Custom transports may be able to reuse this helper when they
    #  execute requests through a Net::HTTP-compatible client, or
    #  implement their own request execution path instead.
    def perform_request(client, request, stream, &b)
      if stream
        client.request(request) do |raw|
          res = LLM::Transport::Response.from(raw)
          if res.success?
            parser = stream.decoder.new(stream.parser.new(stream.streamer))
            res.read_body(parser)
            body = parser.body
            res.body = (Hash === body || Array === body) ? LLM::Object.from(body) : body
          else
            body = +""
            res.read_body { body << _1 }
            res.body = body
          end
        ensure
          parser&.free
        end
      elsif b
        client.request(request) do |raw|
          res = LLM::Transport::Response.from(raw)
          res.success? ? b.call(res) : res
        end
      else
        LLM::Transport::Response.from(client.request(request))
      end
    end
  end
end
