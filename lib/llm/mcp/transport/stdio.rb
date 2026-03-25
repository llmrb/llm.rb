# frozen_string_literal: true

module LLM::MCP::Transport
  ##
  # The {LLM::MCP::Transport::Stdio LLM::MCP::Transport::Stdio} class
  # provides a stdio transport for {LLM::MCP LLM::MCP}. It sends JSON-RPC
  # messages to an MCP process over stdin and stdout and delegates process
  # lifecycle management to {LLM::MCP::Command LLM::MCP::Command}.
  class Stdio
    ##
    # Returns a new Stdio transport instance.
    # @param command [LLM::MCP::Command]
    #  The command to run for the MCP process
    # @return [LLM::MCP::Transport::Stdio]
    def initialize(command:)
      @command = command
    end

    ##
    # Starts an MCP process over a stdio transport.
    # This method is non-blocking and returns immediately.
    # @raise [LLM::Error]
    #  When the transport is already running
    # @return [void]
    def start
      if command.alive?
        raise LLM::MCP::Error, "MCP transport is already running"
      else
        command.start
      end
    end

    ##
    # Closes the connection to the MCP process.
    # This method is idempotent and can be called multiple times without error.
    # @return [void]
    def stop
      command.stop
    end

    ##
    # Writes a message to the MCP process.
    # @param [Hash] message
    #  The message to write
    # @raise [LLM::Error]
    #  When the transport is not running
    # @return [void]
    def write(message)
      if command.alive?
        command.write(LLM.json.dump(message))
      else
        raise LLM::MCP::Error, "MCP transport is not running"
      end
    end

    ##
    # Reads a message from the MCP process without blocking.
    # @raise [LLM::Error]
    #  When the transport is not running
    # @raise [IO::WaitReadable]
    #  When no complete message is available to read
    # @return [Hash]
    #  The next message from the MCP process
    def read_nonblock
      if command.alive?
        LLM.json.load(command.read_nonblock)
      else
        raise LLM::MCP::Error, "MCP transport is not running"
      end
    end

    ##
    # Waits for the command to exit.
    # This method is blocking and will return only after the
    # process has exited.
    # @return [void]
    def wait
      command.wait
    end

    private

    attr_reader :command, :stdin, :stdout, :stderr
  end
end
