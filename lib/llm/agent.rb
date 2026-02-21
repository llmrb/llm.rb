# frozen_string_literal: true

module LLM
  ##
  # {LLM::Agent LLM::Agent} provides a class-level DSL for defining
  # reusable, preconfigured assistants with defaults for model,
  # tools, schema, and instructions.
  #
  # @note
  # Unlike {LLM::Session LLM::Session}, this class will automatically run
  # tool calls for you.
  #
  # @note
  #  Instructions are injected only on the first request.
  #
  # @note
  #  This idea originally came from RubyLLM and was adapted to llm.rb.
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
    # @param [LLM::Provider] provider
    #  A provider
    # @param [Hash] params
    #  The parameters to maintain throughout the conversation.
    #  Any parameter the provider supports can be included and
    #  not only those listed here.
    # @option params [String] :model Defaults to the provider's default model
    # @option params [Array<LLM::Function>, nil] :tools Defaults to nil
    # @option params [#to_json, nil] :schema Defaults to nil
    def initialize(provider, params = {})
      defaults = {model: self.class.model, tools: self.class.tools, schema: self.class.schema}.compact
      @provider = provider
      @ses = LLM::Session.new(provider, defaults.merge(params))
      @instructions_applied = false
    end

    ##
    # Maintain a conversation via the chat completions API.
    # This method immediately sends a request to the LLM and returns the response.
    #
    # @param prompt (see LLM::Provider#complete)
    # @param [Hash] params The params passed to the provider, including optional :stream, :tools, :schema etc.
    # @option params [Integer] :max_tool_rounds The maxinum number of tool call iterations (default 10)
    # @return [LLM::Response] Returns the LLM's response for this turn.
    # @example
    #   llm = LLM.openai(key: ENV["KEY"])
    #   agent = LLM::Agent.new(llm)
    #   response = agent.talk("Hello, what is your name?")
    #   puts response.choices[0].content
    def talk(prompt, params = {})
      i, max = 0, Integer(params.delete(:max_tool_rounds) || 10)
      res = @ses.talk(apply_instructions(prompt), params)
      until @ses.functions.empty?
        raise LLM::ToolLoopError, "pending tool calls remain" if i >= max
        res = @ses.talk @ses.functions.map(&:call), params
        i += 1
      end
      @instructions_applied = true
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
    # @option params [Integer] :max_tool_rounds The maxinum number of tool call iterations (default 10)
    # @return [LLM::Response] Returns the LLM's response for this turn.
    # @example
    #   llm = LLM.openai(key: ENV["KEY"])
    #   agent = LLM::Agent.new(llm)
    #   res = agent.respond("What is the capital of France?")
    #   puts res.output_text
    def respond(prompt, params = {})
      i, max = 0, Integer(params.delete(:max_tool_rounds) || 10)
      res = @ses.respond(apply_instructions(prompt), params)
      until @ses.functions.empty?
        raise LLM::ToolLoopError, "pending tool calls remain" if i >= max
        res = @ses.respond @ses.functions.map(&:call), params
        i += 1
      end
      @instructions_applied = true
      res
    end

    ##
    # @return [LLM::Buffer<LLM::Message>]
    def messages
      @ses.messages
    end

    ##
    # @return [Array<LLM::Function>]
    def functions
      @ses.functions
    end

    ##
    # @return [LLM::Object]
    def usage
      @ses.usage
    end

    ##
    # @return [LLM::Builder]
    def build_prompt(&)
      @ses.build_prompt(&)
    end

    ##
    # @param [String] url
    #  The URL
    # @return [LLM::Object]
    #  Returns a tagged object
    def image_url(url)
      @ses.image_url(url)
    end

    ##
    # @param [String] path
    #  The path
    # @return [LLM::Object]
    #  Returns a tagged object
    def local_file(path)
      @ses.local_file(path)
    end

    ##
    # @param [LLM::Response] res
    #  The response
    # @return [LLM::Object]
    #  Returns a tagged object
    def remote_file(res)
      @ses.remote_file(res)
    end

    ##
    # @return [LLM::Tracer]
    #  Returns an LLM tracer
    def tracer
      @ses.tracer
    end

    ##
    # Returns the model an Agent is actively using
    # @return [String]
    def model
      @ses.model
    end

    private

    def apply_instructions(prompt)
      instr = self.class.instructions
      return prompt unless instr
      if LLM::Builder === prompt
        messages = prompt.to_a
        builder = LLM::Builder.new(@provider) do |builder|
          builder.system instr unless @instructions_applied
          messages.each { |msg| builder.talk(msg.content, role: msg.role) }
        end
        builder.tap(&:call)
      else
        build_prompt do
          _1.system instr unless @instructions_applied
          _1.user prompt
        end
      end
    end
  end
end
