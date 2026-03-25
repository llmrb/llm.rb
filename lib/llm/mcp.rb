# frozen_string_literal: true

##
# The {LLM::MCP LLM::MCP} class provides access to servers that
# implement the Model Context Protocol. MCP defines a standard way for
# clients and servers to exchange capabilities such as tools, prompts,
# resources, and other structured interactions.
#
# In llm.rb, {LLM::MCP LLM::MCP} currently supports stdio servers and
# focuses on discovering tools that can be used through
# {LLM::Session LLM::Session} and {LLM::Agent LLM::Agent}.
class LLM::MCP
  require "monitor"
  require_relative "mcp/error"
  require_relative "mcp/command"
  require_relative "mcp/rpc"
  require_relative "mcp/pipe"
  require_relative "mcp/transport/stdio"

  include RPC

  ##
  # @param [LLM::Provider, nil] llm
  #  The provider to use for MCP transports that need one
  # @param [Hash] stdio The configuration for the stdio transport
  # @option stdio [Array<String>] :argv
  #  The command to run for the MCP process
  # @option stdio [Hash] :env
  #  The environment variables to set for the MCP process
  # @option stdio [String, nil] :cwd
  #  The working directory for the MCP process
  # @param [Integer] timeout The maximum amount of time to wait when reading from an MCP process
  # @return [LLM::MCP] A new MCP instance
  def initialize(llm = nil, stdio:, timeout: 5)
    @llm = llm
    @command = Command.new(**stdio)
    @monitor = Monitor.new
    @transport = Transport::Stdio.new(command:)
    @timeout = timeout
  end

  ##
  # Starts the MCP process.
  # @return [void]
  def start
    lock do
      transport.start
      call(transport, "initialize", {clientInfo: {name: "llm.rb", version: LLM::VERSION}})
      call(transport, "notifications/initialized")
    end
  end

  ##
  # Stops the MCP process.
  # @return [void]
  def stop
    lock do
      transport.stop
      nil
    end
  end

  ##
  # Returns the tools provided by the MCP process.
  # @return [Array<Class<LLM::Tool>>]
  def tools
    lock do
      res = call(transport, "tools/list")
      res["tools"].map { LLM::Tool.mcp(self, _1) }
    end
  end

  ##
  # Calls a tool by name with the given arguments
  # @param [String] name The name of the tool to call
  # @param [Hash] arguments The arguments to pass to the tool
  # @return [Object] The result of the tool call
  def call_tool(name, arguments = {})
    lock do
      res = call(transport, "tools/call", {name:, arguments:})
      adapt_tool_result(res)
    end
  end

  private

  attr_reader :llm, :command, :transport, :timeout

  def adapt_tool_result(result)
    if result["structuredContent"]
      result["structuredContent"]
    elsif result["content"]
      {content: result["content"]}
    else
      result
    end
  end

  def lock(&)
    @monitor.synchronize(&)
  end
end
