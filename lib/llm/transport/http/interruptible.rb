# frozen_string_literal: true

class LLM::Transport::HTTP
  ##
  # Internal request interruption methods for
  # {LLM::Transport::HTTP}.
  #
  # This module tracks active requests by execution owner and provides
  # the logic used to interrupt an in-flight request by closing the
  # active HTTP connection.
  #
  # @api private
  module Interruptible
    INTERRUPT_ERRORS = [::IOError, ::EOFError, Errno::EBADF].freeze
    Request = Struct.new(:http, :connection, keyword_init: true)

    def interrupt_errors
      [*INTERRUPT_ERRORS, *optional_interrupt_errors]
    end

    ##
    # Interrupt an active request, if any.
    # @param [Fiber] owner
    #  The execution owner whose request should be interrupted
    # @return [nil]
    def interrupt!(owner)
      req = request_for(owner) or return
      lock { (@interrupts ||= {})[owner] = true }
      if persistent_http?(req.http)
        close_socket(req.connection&.http)
        req.http.finish(req.connection)
      elsif transient_http?(req.http)
        close_socket(req.http)
        req.http.finish if req.http.active?
      end
      owner.stop if owner.respond_to?(:stop)
    rescue *interrupt_errors
      nil
    end

    private

    ##
    # Closes the active socket for a request, if present.
    # @param [Net::HTTP, nil] http
    # @return [nil]
    def close_socket(http)
      socket = http&.instance_variable_get(:@socket) or return
      socket = socket.io if socket.respond_to?(:io)
      socket.close
    rescue *interrupt_errors
      nil
    end

    ##
    # Returns whether the active request is using a transient HTTP client.
    # @param [Object, nil] http
    # @return [Boolean]
    def transient_http?(http)
      Net::HTTP === http
    end

    ##
    # Returns whether the active request is using a persistent HTTP client.
    # @param [Object, nil] http
    # @return [Boolean]
    def persistent_http?(http)
      defined?(Net::HTTP::Persistent) && Net::HTTP::Persistent === http
    end

    ##
    # Returns the active request for an execution owner.
    # @param [Fiber] owner
    # @return [Request, nil]
    def request_for(owner)
      lock do
        @requests ||= {}
        @requests[owner]
      end
    end

    ##
    # Records an active request for an execution owner.
    # @param [Request] req
    # @param [Fiber] owner
    # @return [Request]
    def set_request(req, owner)
      lock do
        @requests ||= {}
        @requests[owner] = req
      end
    end

    ##
    # Clears the active request for an execution owner.
    # @param [Fiber] owner
    # @return [Request, nil]
    def clear_request(owner)
      lock { @requests&.delete(owner) }
    end

    ##
    # Returns whether an execution owner was interrupted.
    # @param [Fiber] owner
    # @return [Boolean, nil]
    def interrupted?(owner)
      lock { @interrupts&.delete(owner) }
    end

    def optional_interrupt_errors
      defined?(::Async::Stop) ? [Async::Stop] : []
    end
  end
end
