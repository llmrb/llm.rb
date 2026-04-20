# frozen_string_literal: true

module LLM
  ##
  # {LLM::Agent LLM::Agent} provides a class-level DSL for defining
  # reusable, preconfigured assistants with defaults for model,
  # tools, schema, and instructions.
  #
  # It wraps the same stateful runtime surface as
  # {LLM::Context LLM::Context}: message history, usage, persistence,
  # streaming parameters, and provider-backed requests still flow through
  # an underlying context. The defining behavior of an agent is that it
  # automatically resolves pending tool calls for you during `talk` and
  # `respond`, instead of leaving tool loops to the caller.
  #
  # **Notes:**
  # * Instructions are injected only on the first request.
  # * An agent automatically executes tool loops (unlike {LLM::Context LLM::Context}).
  # * Tool loop execution can be configured with `concurrency :call`,
  #   `:thread`, `:task`, `:fiber`, `:ractor`, or a list of queued task
  #   types such as `[:thread, :ractor]`.
  #
  # @example
  #   class SystemAdmin < LLM::Agent
  #     model "gpt-4.1-nano"
  #     instructions "You are a Linux system admin"
  #     tools Shell
  #     schema Result
  #   end
  #
  #   llm = LLM.openai(key: ENV["KEY"])
  #   agent = SystemAdmin.new(llm)
  #   agent.talk("Run 'date'")
  class Agent
    ##
    # Returns a provider
    # @return [LLM::Provider]
    attr_reader :llm

    ##
    # Set or get the default model
    # @param [String, nil] model
    #  The model identifier
    # @return [String, nil]
    #  Returns the current model when no argument is provided
    def self.model(model = nil)
      return @model if model.nil?
      @model = model
    end

    ##
    # Set or get the default tools
    # @param [Array<LLM::Function>, nil] tools
    #  One or more tools
    # @return [Array<LLM::Function>]
    #  Returns the current tools when no argument is provided
    def self.tools(*tools)
      return @tools || [] if tools.empty?
      @tools = tools.flatten
    end

    ##
    # Set or get the default skills
    # @param [Array<String>, nil] skills
    #  One or more skill directories
    # @return [Array<String>, nil]
    #  Returns the current skills when no argument is provided
    def self.skills(*skills)
      return @skills if skills.empty?
      @skills = skills.flatten
    end

    ##
    # Set or get the default schema
    # @param [#to_json, nil] schema
    #  The schema
    # @return [#to_json, nil]
    #  Returns the current schema when no argument is provided
    def self.schema(schema = nil)
      return @schema if schema.nil?
      @schema = schema
    end

    ##
    # Set or get the default instructions
    # @param [String, nil] instructions
    #  The system instructions
    # @return [String, nil]
    #  Returns the current instructions when no argument is provided
    def self.instructions(instructions = nil)
      return @instructions if instructions.nil?
      @instructions = instructions
    end

    ##
    # Set or get the tool execution concurrency.
    #
    # @param [Symbol, Array<Symbol>, nil] concurrency
    #  Controls how pending tool loops are executed:
    #  - `:call`: sequential calls
    #  - `:thread`: concurrent threads
    #  - `:task`: concurrent async tasks
    #  - `:fiber`: concurrent raw fibers
    #  - `:ractor`: concurrent Ruby ractors for class-based tools; MCP tools are not supported,
    #    and this mode is especially useful for CPU-bound tool work
    #  - `[:thread, :ractor]`: the possible concurrency strategies to wait on, in the
    #    given order. This is useful for mixed tool sets or when work may have been
    #    spawned with more than one concurrency strategy.
    # @return [Symbol, Array<Symbol>, nil]
    def self.concurrency(concurrency = nil)
      return @concurrency if concurrency.nil?
      @concurrency = concurrency
    end

    ##
    # @param [LLM::Provider] provider
    #  A provider
    # @param [Hash] params
    #  The parameters to maintain throughout the conversation.
    #  Any parameter the provider supports can be included and
    #  not only those listed here.
    # @option params [String] :model Defaults to the provider's default model
    # @option params [Array<LLM::Function>, nil] :tools Defaults to nil
    # @option params [Array<String>, nil] :skills Defaults to nil
    # @option params [#to_json, nil] :schema Defaults to nil
    # @option params [Symbol, Array<Symbol>, nil] :concurrency Defaults to the agent class concurrency
    def initialize(llm, params = {})
      defaults = {model: self.class.model, tools: self.class.tools, skills: self.class.skills, schema: self.class.schema}.compact
      @concurrency = params.delete(:concurrency) || self.class.concurrency
      @llm = llm
      @ctx = LLM::Context.new(llm, defaults.merge(params))
    end

    ##
    # Maintain a conversation via the chat completions API.
    # This method immediately sends a request to the LLM and returns the response.
    #
    # @param prompt (see LLM::Provider#complete)
    # @param [Hash] params The params passed to the provider, including optional :stream, :tools, :schema etc.
    # @option params [Integer] :tool_attempts The maxinum number of tool call iterations (default 10)
    # @return [LLM::Response] Returns the LLM's response for this turn.
    # @example
    #   llm = LLM.openai(key: ENV["KEY"])
    #   agent = LLM::Agent.new(llm)
    #   response = agent.talk("Hello, what is your name?")
    #   puts response.choices[0].content
    def talk(prompt, params = {})
      max = Integer(params.delete(:tool_attempts) || 10)
      res = @ctx.talk(apply_instructions(prompt), params)
      max.times do
        break if @ctx.functions.empty?
        res = @ctx.talk(call_functions, params)
      end
      raise LLM::ToolLoopError, "pending tool calls remain" unless @ctx.functions.empty?
      res
    end
    alias_method :chat, :talk

    ##
    # Maintain a conversation via the responses API.
    # This method immediately sends a request to the LLM and returns the response.
    #
    # @note Not all LLM providers support this API
    # @param prompt (see LLM::Provider#complete)
    # @param [Hash] params The params passed to the provider, including optional :stream, :tools, :schema etc.
    # @option params [Integer] :tool_attempts The maxinum number of tool call iterations (default 10)
    # @return [LLM::Response] Returns the LLM's response for this turn.
    # @example
    #   llm = LLM.openai(key: ENV["KEY"])
    #   agent = LLM::Agent.new(llm)
    #   res = agent.respond("What is the capital of France?")
    #   puts res.output_text
    def respond(prompt, params = {})
      max = Integer(params.delete(:tool_attempts) || 10)
      res = @ctx.respond(apply_instructions(prompt), params)
      max.times do
        break if @ctx.functions.empty?
        res = @ctx.respond(call_functions, params)
      end
      raise LLM::ToolLoopError, "pending tool calls remain" unless @ctx.functions.empty?
      res
    end

    ##
    # @return [LLM::Buffer<LLM::Message>]
    def messages
      @ctx.messages
    end

    ##
    # @return [Array<LLM::Function>]
    def functions
      @ctx.functions
    end

    ##
    # @see LLM::Context#returns
    # @return [Array<LLM::Function::Return>]
    def returns
      @ctx.returns
    end

    ##
    # @see LLM::Context#call
    # @return [Object]
    def call(...)
      @ctx.call(...)
    end

    ##
    # @see LLM::Context#wait
    # @return [Array<LLM::Function::Return>]
    def wait(...)
      @ctx.wait(...)
    end

    ##
    # @return [LLM::Object]
    def usage
      @ctx.usage
    end

    ##
    # Interrupt the active request, if any.
    # @return [nil]
    def interrupt!
      @ctx.interrupt!
    end
    alias_method :cancel!, :interrupt!

    ##
    # @param (see LLM::Context#prompt)
    # @return (see LLM::Context#prompt)
    # @see LLM::Context#prompt
    def prompt(&b)
      @ctx.prompt(&b)
    end
    alias_method :build_prompt, :prompt

    ##
    # @param [String] url
    #  The URL
    # @return [LLM::Object]
    #  Returns a tagged object
    def image_url(url)
      @ctx.image_url(url)
    end

    ##
    # @param [String] path
    #  The path
    # @return [LLM::Object]
    #  Returns a tagged object
    def local_file(path)
      @ctx.local_file(path)
    end

    ##
    # @param [LLM::Response] res
    #  The response
    # @return [LLM::Object]
    #  Returns a tagged object
    def remote_file(res)
      @ctx.remote_file(res)
    end

    ##
    # @return [LLM::Tracer]
    #  Returns an LLM tracer
    def tracer
      @ctx.tracer
    end

    ##
    # Returns the model an Agent is actively using
    # @return [String]
    def model
      @ctx.model
    end

    ##
    # @return [Symbol]
    def mode
      @ctx.mode
    end

    ##
    # Returns the configured tool execution concurrency.
    # @return [Symbol, Array<Symbol>, nil]
    def concurrency
      @concurrency
    end

    ##
    # @see LLM::Context#cost
    # @return [LLM::Cost]
    def cost
      @ctx.cost
    end

    ##
    # @see LLM::Context#context_window
    # @return [Integer]
    def context_window
      @ctx.context_window
    end

    ##
    # @see LLM::Context#to_h
    # @return [Hash]
    def to_h
      @ctx.to_h
    end

    ##
    # @return [String]
    def to_json(...)
      to_h.to_json(...)
    end

    ##
    # @return [String]
    def inspect
      "#<#{self.class.name}:0x#{object_id.to_s(16)} " \
      "@llm=#{@llm.class}, @mode=#{mode.inspect}, @messages=#{messages.inspect}>"
    end

    ##
    # @param (see LLM::Context#serialize)
    # @return (see LLM::Context#serialize)
    def serialize(**kw)
      @ctx.serialize(**kw)
    end
    alias_method :save, :serialize

    ##
    # @param (see LLM::Context#deserialize)
    # @return (see LLM::Context#deserialize)
    def deserialize(**kw)
      @ctx.deserialize(**kw)
    end
    alias_method :restore, :deserialize

    private

    ##
    # @return [LLM::Prompt]
    def apply_instructions(new_prompt)
      instr = self.class.instructions
      return new_prompt unless instr
      if LLM::Prompt === new_prompt
        new_prompt.system(instr) if @ctx.messages.empty?
        new_prompt
      else
        prompt do
          _1.system(instr) if @ctx.messages.empty?
          _1.user(new_prompt)
        end
      end
    end

    ##
    # @return [Array<LLM::Function::Return>]
    def call_functions
      case concurrency || :call
      when :call then call(:functions)
      when :thread, :task, :fiber, :ractor, Array then wait(concurrency)
      else raise ArgumentError, "Unknown concurrency: #{concurrency.inspect}. Expected :call, :thread, :task, :fiber, :ractor, or an array of queued task types"
      end
    end
  end
end
