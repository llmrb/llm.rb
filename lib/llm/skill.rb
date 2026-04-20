# frozen_string_literal: true

module LLM
  ##
  # {LLM::Skill LLM::Skill} represents a directory-backed packaged capability.
  # A skill directory must contain a `SKILL.md` file with YAML frontmatter.
  # Skills can expose themselves as normal {LLM::Tool LLM::Tool} classes through
  # {#to_tool}. This keeps skills on the same execution path as local tools.
  class Skill
    ##
    # Load a skill from a directory.
    # @param [String, Pathname] path
    # @return [LLM::Skill]
    def self.load(path)
      new(path).tap(&:load!)
    end

    ##
    # Returns the skill directory.
    # @return [String]
    attr_reader :path

    ##
    # Returns the skill name.
    # @return [String]
    attr_reader :name

    ##
    # Returns the skill description.
    # @return [String]
    attr_reader :description

    ##
    # Returns the skill instructions.
    # @return [String]
    attr_reader :instructions

    ##
    # Returns the skill frontmatter.
    # @return [LLM::Object]
    attr_reader :frontmatter

    ##
    # Returns the skill tools.
    # @return [Array<Class<LLM::Tool>>]
    attr_reader :tools

    def initialize(path)
      @path = path.to_s
      @name = ::File.basename(@path)
      @description = "Skill: #{@name}"
      @instructions = ""
      @frontmatter = LLM::Object.from({})
      @tools = []
    end

    ##
    # Load and parse the skill.
    # @return [LLM::Skill]
    def load!
      path = ::File.join(@path, "SKILL.md")
      parse(::File.read(path))
      self
    end

    ##
    # Execute the skill by wrapping it in a small agent with the skill
    # instructions. The provider is bound explicitly by the caller.
    # @param [LLM::Provider] llm
    # @param [Hash] input
    # @return [Hash]
    def call(llm, **)
      instructions = self.instructions
      tools = self.tools
      agent = Class.new(LLM::Agent) do
        instructions instructions
        tools(*tools)
      end.new(llm)
      res = agent.talk(instructions)
      {content: res.content}
    end

    ##
    # Expose the skill as a normal LLM::Tool. The provider is bound explicitly
    # when the tool class is built.
    # @param [LLM::Provider] llm
    # @return [Class<LLM::Tool>]
    def to_tool(llm)
      skill = self
      Class.new(LLM::Tool) do
        name skill.name
        description skill.description

        define_method(:call) do |**input|
          skill.call(llm, **input)
        end
      end
    end

    private

    def parse(content)
      match = content.match(/\A---\s*\n(.*?)\n---\s*\n?(.*)\z/m)
      unless match
        @instructions = content
        return
      end
      require "yaml" unless defined?(::YAML)
      @frontmatter = LLM::Object.from(YAML.safe_load(match[1]) || {})
      @name = @frontmatter.name || @name
      @description = @frontmatter.description || @description
      @tools = [*@frontmatter.tools].map { LLM::Tool.find_by_name!(_1) }
      @instructions = match[2]
    end
  end
end
