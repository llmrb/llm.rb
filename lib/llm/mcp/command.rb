# frozen_string_literal: true

class LLM::MCP
  ##
  # The {LLM::MCP::Command} class manages the lifecycle of an MCP process
  # by wrapping a system command. It provides methods to start the process,
  # write to its stdin, read from its stdout and stderr, and wait for it
  # to exit.
  class Command
    ##
    # @return [Integer, nil]
    #  The PID of the running command, or nil if it's not running
    attr_reader :pid

    attr_reader :stdin, :stdout, :stderr

    ##
    # @param [Array<String>] argv The command to run for the MCP process
    # @param [Hash] env The environment variables to set for the MCP process
    # @param [String, nil] cwd The working directory for the MCP process
    # @return [LLM::MCP::Command] A new Command instance
    def initialize(argv:, env: {}, cwd: nil)
      @argv = argv
      @env = env
      @cwd = cwd
      @pid = nil
      @buffers = {}
    end

    ##
    # Starts a command.
    # @raise [LLM::Error]
    #  When the command is already running
    # @return [void]
    def start
      raise LLM::MCP::Error, "MCP command is already running" if alive?
      @stdout, @stderr, @stdin = 3.times.map { Pipe.new }
      @buffers.clear
      @pid = Process.spawn(env, *argv, {chdir: cwd, out: stdout.w, err: stderr.w, in: stdin.r}.compact)
      [stdin.close_reader, [stdout, stderr].each(&:close_writer)]
    end

    ##
    # Stops the command if it's running.
    # @return [void]
    def stop
      return nil unless alive?
      [stdin.close_writer, [stdout, stderr].each(&:close_reader)]
      Process.kill("TERM", pid)
      @buffers.clear
      wait
    end

    ##
    # Returns true when command is running.
    # @return [Boolean]
    def alive?
      !@pid.nil?
    end

    ##
    # Writes to the command's stdin
    # @param [String] message The message to write
    # @return [void]
    def write(message)
      stdin.write(message)
      stdin.write("\n")
      stdin.flush
    end

    ##
    # Reads from the command's IO without blocking.
    # @param [Symbol] io
    #  The IO stream to read from (:stdout, :stderr)
    # @raise [LLM::Error]
    #  When the command is not running
    # @raise [IO::WaitReadable]
    #  When no complete message is available to read
    # @return [String]
    #  The next complete line from the specified IO stream
    def read_nonblock(io = :stdout)
      raise LLM::MCP::Error, "MCP command is not running" unless alive?
      io = public_send(io)
      @buffers[io] ||= +""
      loop do
        if (index = @buffers[io].index("\n"))
          return @buffers[io].slice!(0, index + 1)
        end
        @buffers[io] << io.read_nonblock(4096)
      end
    end

    ##
    # Waits for the command to exit and returns its exit status.
    # @return [Process::Status, nil]
    #  The exit status of the command, or nil
    def wait
      Process.wait(pid)
      @pid = nil
    rescue Errno::ECHILD
      nil
    end

    private

    attr_reader :argv, :env, :cwd
  end
end
