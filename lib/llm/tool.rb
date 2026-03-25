# frozen_string_literal: true

##
# The {LLM::Tool LLM::Tool} class represents a local tool
# that can be called by an LLM. Under the hood, it is a wrapper
# around {LLM::Function LLM::Function} but allows the definition
# of a function (also known as a tool) as a class.
# @example
#   class System < LLM::Tool
#     name "system"
#     description "Runs system commands"
#     params do |schema|
#       schema.object(command: schema.string.required)
#     end
#
#     def call(command:)
#       {success: Kernel.system(command)}
#     end
#   end
class LLM::Tool
  require_relative "tool/param"
  extend LLM::Tool::Param

  types = [
    :Leaf, :String, :Enum, :Array,
    :Object, :Integer, :Number,
    :Boolean, :Null
  ]
  types.each do |constant|
    const_set constant, LLM::Schema.const_get(constant)
  end

  ##
  # @param [LLM::MCP] mcp
  #  The MCP client that will execute the tool call
  # @param [Hash] tool
  #  A tool (as a raw Hash)
  # @return [Class<LLM::Tool>]
  #  Returns a subclass of LLM::Tool
  def self.mcp(mcp, tool)
    Class.new(LLM::Tool) do
      name tool["name"]
      description tool["description"]
      params { tool["inputSchema"] || {type: "object", properties: {}} }

      define_method(:call) do |**args|
        mcp.call_tool(tool["name"], args)
      end
    end
  end

  ##
  # Returns all subclasses of LLM::Tool
  # @note
  #  This method excludes tools who haven't defined a name
  # @return [Array<LLM::Tool>]
  def self.registry
    @registry.select(&:name)
  end
  @registry = []

  ##
  # Clear the registry
  # @return [void]
  def self.clear_registry!
    @registry.clear
    nil
  end

  ##
  # Register a tool in the registry
  # @param [LLM::Tool] tool
  # @api private
  def self.register(tool)
    @registry << tool
  end

  ##
  # Registers the tool as a function when inherited
  # @param [Class] klass The subclass
  # @return [void]
  def self.inherited(tool)
    LLM.lock(:inherited) do
      tool.instance_eval { @__monitor ||= Monitor.new }
      tool.function.register(tool)
      LLM::Tool.register(tool)
    end
  end

  ##
  # Returns (or sets) the tool name
  # @param [String, nil] name The tool name
  # @return [String]
  def self.name(name = nil)
    lock do
      name ? function.name(name) : function.name
    end
  end

  ##
  # Returns (or sets) the tool description
  # @param [String, nil] desc The tool description
  # @return [String]
  def self.description(desc = nil)
    lock do
      desc ? function.description(desc) : function.description
    end
  end

  ##
  # Returns (or sets) tool parameters
  # @yieldparam [LLM::Schema] schema The schema object to define parameters
  # @return [LLM::Schema]
  def self.params(&)
    lock do
      function.tap { _1.params(&) }
    end
  end

  ##
  # @api private
  def self.function
    lock do
      @function ||= LLM::Function.new(nil)
    end
  end

  ##
  # @api private
  def self.lock(&)
    @__monitor.synchronize(&)
  end
end
