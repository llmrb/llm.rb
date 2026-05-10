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
    require_relative "transport/execution"

    ##
    # Performs a request through the transport.
    # @param [Net::HTTPRequest] request
    # @param [Object] owner
    # @yieldparam [Object] client
    # @return [Object]
    def request(request, owner:, &)
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

    ##
    # Configures the transport to use persistence, if supported.
    # @return [LLM::Transport]
    def persist!
      self
    end
    alias_method :persistent, :persist!

    ##
    # Returns whether the transport is persistent.
    # @return [Boolean]
    def persistent?
      false
    end
  end
end
