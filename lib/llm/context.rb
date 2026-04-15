# frozen_string_literal: true

module LLM
  ##
  # {LLM::Context LLM::Context} is the stateful execution boundary in
  # llm.rb.
  #
  # It holds the evolving runtime state for an LLM workflow:
  # conversation history, tool calls and returns, schema and streaming
  # configuration, accumulated usage, and request ownership for
  # interruption.
  #
  # This is broader than prompt context alone. A context is the object
  # that lets one-off prompts, streaming turns, tool execution,
  # persistence, retries, and serialized long-lived workflows all run
  # through the same model.
  #
  # A context can drive the chat completions API that all providers
  # support or the Responses API on providers that expose it.
  #
  # @example
  #   #!/usr/bin/env ruby
  #   require "llm"
  #
  #   llm = LLM.openai(key: ENV["KEY"])
  #   ctx = LLM::Context.new(llm)
  #
  #   prompt = LLM::Prompt.new(llm) do
  #     system "Be concise and show your reasoning briefly."
  #     user "If a train goes 60 mph for 1.5 hours, how far does it travel?"
  #     user "Now double the speed for the same time."
  #   end
  #
  #   ctx.talk(prompt)
  #   ctx.messages.each { |m| puts "[#{m.role}] #{m.content}" }
  class Context
    require_relative "context/deserializer"
    include Deserializer

    ##
    # Returns the accumulated message history for this context
    # @return [LLM::Buffer<LLM::Message>]
    attr_reader :messages

    ##
    # Returns a provider
    # @return [LLM::Provider]
    attr_reader :llm

    ##
    # Returns the context mode
    # @return [Symbol]
    attr_reader :mode

    ##
    # @param [LLM::Provider] llm
    #  A provider
    # @param [Hash] params
    #  The parameters to maintain throughout the conversation.
    #  Any parameter the provider supports can be included and
    #  not only those listed here.
    # @option params [Symbol] :mode Defaults to :completions
    # @option params [String] :model Defaults to the provider's default model
    # @option params [Array<LLM::Function>, nil] :tools Defaults to nil
    def initialize(llm, params = {})
      @llm = llm
      @mode = params.delete(:mode) || :completions
      @params = {model: llm.default_model, schema: nil}.compact.merge!(params)
      @messages = LLM::Buffer.new(llm)
      @owner = Fiber.current
    end

    ##
    # Interact with the context via the chat completions API.
    # This method immediately sends a request to the LLM and returns the response.
    #
    # @param prompt (see LLM::Provider#complete)
    # @param params The params, including optional :role (defaults to :user), :stream, :tools, :schema etc.
    # @return [LLM::Response] Returns the LLM's response for this turn.
    # @example
    #   llm = LLM.openai(key: ENV["KEY"])
    #   ctx = LLM::Context.new(llm)
    #   res = ctx.talk("Hello, what is your name?")
    #   puts res.messages[0].content
    def talk(prompt, params = {})
      return respond(prompt, params) if mode == :responses
      params = params.merge(messages: @messages.to_a)
      params = @params.merge(params)
      res = @llm.complete(prompt, params)
      role = params[:role] || @llm.user_role
      role = @llm.tool_role if params[:role].nil? && [*prompt].grep(LLM::Function::Return).any?
      @messages.concat LLM::Prompt === prompt ? prompt.to_a : [LLM::Message.new(role, prompt)]
      @messages.concat [res.choices[-1]]
      res
    end
    alias_method :chat, :talk

    ##
    # Interact with the context via the responses API.
    # This method immediately sends a request to the LLM and returns the response.
    #
    # @note Not all LLM providers support this API
    # @param prompt (see LLM::Provider#complete)
    # @param params The params, including optional :role (defaults to :user), :stream, :tools, :schema etc.
    # @return [LLM::Response] Returns the LLM's response for this turn.
    # @example
    #   llm = LLM.openai(key: ENV["KEY"])
    #   ctx = LLM::Context.new(llm)
    #   res = ctx.respond("What is the capital of France?")
    #   puts res.output_text
    def respond(prompt, params = {})
      params = @params.merge(params)
      res_id = params[:store] == false ? nil : @messages.find(&:assistant?)&.response&.response_id
      params = params.merge(previous_response_id: res_id, input: @messages.to_a).compact
      res = @llm.responses.create(prompt, params)
      role = params[:role] || @llm.user_role
      @messages.concat LLM::Prompt === prompt ? prompt.to_a : [LLM::Message.new(role, prompt)]
      @messages.concat [res.choices[-1]]
      res
    end

    ##
    # @return [String]
    def inspect
      "#<#{self.class.name}:0x#{object_id.to_s(16)} " \
      "@llm=#{@llm.class}, @mode=#{@mode.inspect}, @params=#{@params.inspect}, " \
      "@messages=#{@messages.inspect}>"
    end

    ##
    # Returns an array of functions that can be called
    # @return [Array<LLM::Function>]
    def functions
      return_ids = returns.map(&:id)
      @messages
        .select(&:assistant?)
        .flat_map do |msg|
          fns = msg.functions.select { _1.pending? && !return_ids.include?(_1.id) }
          fns.each do |fn|
            fn.tracer = tracer
            fn.model  = msg.model
          end
        end.extend(LLM::Function::Array)
    end

    ##
    # Calls a named collection of work through the context.
    #
    # This currently supports `:functions`, forwarding to `functions.call`.
    #
    # @param [Symbol] target
    #  The work collection to call
    # @return [Array<LLM::Function::Return>]
    def call(target)
      case target
      when :functions then functions.call
      else raise ArgumentError, "Unknown target: #{target.inspect}. Expected :functions"
      end
    end

    ##
    # Returns tool returns accumulated in this context
    # @return [Array<LLM::Function::Return>]
    def returns
      @messages
        .select(&:tool_return?)
        .flat_map do |msg|
          LLM::Function::Return === msg.content ?
            [msg.content] :
            [*msg.content].grep(LLM::Function::Return)
        end
    end

    ##
    # Waits for queued tool work to finish.
    #
    # This prefers queued streamed tool work when the configured stream
    # exposes a non-empty queue. Otherwise it falls back to waiting on
    # the context's pending functions directly.
    #
    # @param [Symbol] strategy
    #  The concurrency strategy to use
    # @return [Array<LLM::Function::Return>]
    def wait(strategy)
      stream = @params[:stream]
      if LLM::Stream === stream && !stream.queue.empty?
        stream.wait(strategy)
      else
        functions.wait(strategy)
      end
    end

    ##
    # Interrupt the active request, if any.
    # This is inspired by Go's context cancellation model.
    # @return [nil]
    def interrupt!
      llm.interrupt!(@owner)
    end
    alias_method :cancel!, :interrupt!

    ##
    # Returns token usage accumulated in this context
    # @note
    # This method returns token usage for the latest
    # assistant message, and it returns nil for non-assistant
    # messages.
    # @return [LLM::Object, nil]
    def usage
      @messages.find(&:assistant?)&.usage
    end

    ##
    # Build a role-aware prompt for a single request.
    #
    # Prefer this method over {#build_prompt}. The older
    # method name is kept for backward compatibility.
    # @example
    #   prompt = ctx.prompt do
    #     system "Your task is to assist the user"
    #     user "Hello, can you assist me?"
    #   end
    #   ctx.talk(prompt)
    # @param [Proc] b
    #  A block that composes messages. If it takes one argument,
    #  it receives the prompt object. Otherwise it runs in prompt context.
    # @return [LLM::Prompt]
    def prompt(&b)
      LLM::Prompt.new(@llm, &b)
    end
    alias_method :build_prompt, :prompt

    ##
    # Recongize an object as a URL to an image
    # @param [String] url
    #  The URL
    # @return [LLM::Object]
    #  Returns a tagged object
    def image_url(url)
      LLM::Object.from(value: url, kind: :image_url)
    end

    ##
    # Recongize an object as a local file
    # @param [String] path
    #  The path
    # @return [LLM::Object]
    #  Returns a tagged object
    def local_file(path)
      LLM::Object.from(value: LLM.File(path), kind: :local_file)
    end

    ##
    # Reconginize an object as a remote file
    # @param [LLM::Response] res
    #  The response
    # @return [LLM::Object]
    #  Returns a tagged object
    def remote_file(res)
      LLM::Object.from(value: res, kind: :remote_file)
    end

    ##
    # @return [LLM::Tracer]
    #  Returns an LLM tracer
    def tracer
      @llm.tracer
    end

    ##
    # Returns the model a Context is actively using
    # @return [String]
    def model
      messages.find(&:assistant?)&.model || @params[:model]
    end

    ##
    # @return [Hash]
    def to_h
      {schema_version: 1, model:, messages:}
    end

    ##
    # @return [String]
    def to_json(...)
      to_h.to_json(...)
    end

    ##
    # Save the current context state
    # @example
    #  llm = LLM.openai(key: ENV["KEY"])
    #  ctx = LLM::Context.new(llm)
    #  ctx.talk "Hello"
    #  ctx.save(path: "context.json")
    # @raise [SystemCallError]
    #  Might raise a number of SystemCallError subclasses
    # @return [void]
    def serialize(path:)
      ::File.binwrite path, LLM.json.dump(self)
    end
    alias_method :save, :serialize

    ##
    # Restore a saved context state
    # @param [String, nil] path
    #  The path to a JSON file
    # @param [String, nil] string
    #  A raw JSON string
    # @raise [SystemCallError]
    #  Might raise a number of SystemCallError subclasses
    # @return [LLM::Context]
    def deserialize(path: nil, string: nil)
      payload = if path.nil? and string.nil?
        raise ArgumentError, "a path or string is required"
      elsif path
        ::File.binread(path)
      else
        string
      end
      ctx = LLM.json.load(payload)
      @messages.concat [*ctx["messages"]].map { deserialize_message(_1) }
      self
    end
    alias_method :restore, :deserialize

    ##
    # @return [LLM::Cost]
    #  Returns an _approximate_ cost for a given context
    #  based on both the provider, and model
    def cost
      return LLM::Cost.new(0, 0) unless usage
      cost = LLM.registry_for(llm).cost(model:)
      LLM::Cost.new(
        (cost.input.to_f / 1_000_000.0)  * usage.input_tokens,
        (cost.output.to_f / 1_000_000.0) * usage.output_tokens
      )
    end

    ##
    # Returns the model's context window.
    # The context window is the maximum amount of input and output
    # tokens a model can consider in a single request.
    # @note
    #   This method returns 0 when the provider or
    #   model can't be found within {LLM::Registry}.
    # @return [Integer]
    def context_window
      LLM
        .registry_for(llm)
        .limit(model:)
        .context
    rescue LLM::NoSuchModelError, LLM::NoSuchRegistryError
      0
    end
  end

  # Backward-compatible alias
  Bot = Context

  # Scheduled for removal in v6.0
  deprecate_constant :Bot
end
