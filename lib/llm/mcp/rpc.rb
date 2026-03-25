# frozen_string_literal: true

class LLM::MCP
  ##
  # The {LLM::MCP::RPC} module provides the JSON-RPC interface used by
  # {LLM::MCP}. MCP uses JSON-RPC to exchange messages between a client
  # and a server. A client sends a method name and its parameters as a
  # request, and the server replies with either a result or an error.
  #
  # This module is responsible for composing those requests, applying
  # the defaults needed by built-in MCP methods such as initialize,
  # and reading responses for request methods. Notifications are sent
  # without waiting for a response, and errors are raised as
  # {LLM::MCP::Error}.
  # @private
  module RPC
    ##
    # Sends a method over the transport.
    # @param [LLM::MCP::Transport] transport
    #  The transport to write to
    # @param [String] method
    #  The method name to call
    # @param [Hash] params
    #  The parameters to send with the method call
    # @return [Object, nil]
    #  The result of the method call, or nil if it's a notification
    def call(transport, method, params = {})
      message = {jsonrpc: "2.0", method:, params: default_params(method).merge(params)}
      if notification?(method)
        transport.write(message)
        nil
      else
        method == "initialize" ? @request_id = 0 : @request_id += 1
        transport.write(message.merge(id: request_id))
        recv transport
      end
    end

    private

    attr_reader :request_id

    ##
    # Reads a response from the transport.
    # @param [LLM::MCP::Transport] transport
    #  The transport to read from
    # @raise [LLM::MCP::Error]
    #  When the MCP process returns an error
    # @return [Object, nil]
    #  The result returned by the MCP process
    def recv(transport)
      poll(timeout:, ex: [IO::WaitReadable]) do
        res = transport.read_nonblock
        if res["error"]
          raise LLM::MCP::Error.from(response: res)
        else
          break res["result"]
        end
      end
    end

    ##
    # Returns default parameters for built-in methods.
    # @param [String] method
    #  The method name
    # @return [Hash]
    def default_params(method)
      case method
      when "initialize"
        {protocolVersion: "2025-03-26", capabilities: {}}
      else
        {}
      end
    end

    ##
    # Returns true when the method is a notification.
    # @param [String] method
    #  The method name
    # @return [Boolean]
    def notification?(method)
      method.to_s.start_with?("notifications/")
    end

    ##
    # Returns the maximum amount of time to wait when reading from an MCP process.
    # @return [Integer]
    def timeout
      @timeout || 5
    end

    ##
    # Runs a block until it succeeds, times out, or raises an unhandled exception.
    # @param [Integer] timeout
    #  The timeout for the block, in seconds
    # @param [Array<Class>] ex
    #  The exceptions to retry when raised
    # @yield
    #  The block to run
    # @raise [LLM::MCP::TimeoutError]
    #  When the block takes longer than the timeout
    # @return [Object]
    def poll(timeout:, ex: [])
      start = Process.clock_gettime(Process::CLOCK_MONOTONIC)
      loop do
        return yield
      rescue *ex
        duration = Process.clock_gettime(Process::CLOCK_MONOTONIC) - start
        raise LLM::MCP::TimeoutError, "MCP process timed out" if duration > timeout
        sleep 0.05
      end
    end
  end
end
