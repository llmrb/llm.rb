# frozen_string_literal: true

class LLM::Provider
  ##
  # The {LLM::Provider::Transport LLM::Provider::Transport} class defines
  # the execution interface used by {LLM::Provider}.
  #
  # Custom transports can subclass this class and override {#request} to
  # execute provider requests without changing request adapters or
  # response adapters.
  #
  # Only {#request} is required. The remaining methods are optional hooks
  # for features such as interruption, request ownership, or persistence,
  # and only need to be implemented when the underlying adapter can
  # support them.
  class Transport
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
    # @return [LLM::Provider::Transport]
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
