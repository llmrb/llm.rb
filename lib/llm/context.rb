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
    require_relative "compactor"
    require_relative "context/serializer"
    require_relative "context/deserializer"
    include Serializer
    include Deserializer

    ZERO_USAGE = LLM::Object.from(
      input_tokens: 0,
      output_tokens: 0,
      reasoning_tokens: 0,
      input_audio_tokens: 0,
      output_audio_tokens: 0,
      input_image_tokens: 0,
      cache_read_tokens: 0,
      cache_write_tokens: 0,
      total_tokens: 0
    )
    private_constant :ZERO_USAGE

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
    # Returns the default params for this context
    # @return [Hash]
    def params
      @params.dup
    end

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
    # @option params [Array<String>, nil] :skills Defaults to nil
    def initialize(llm, params = {})
      @llm = llm
      @mode = params.delete(:mode) || :completions
      @compactor = params.delete(:compactor)
      @guard = params.delete(:guard)
      @transformer = params.delete(:transformer)
      tools = [*params.delete(:tools), *load_skills(params.delete(:skills))]
      @params = {model: llm.default_model, schema: nil}.compact.merge!(params)
      @params[:tools] = tools unless tools.empty?
      @messages = LLM::Buffer.new(llm)
    end

    ##
    # Returns a context compactor
    # This feature is inspired by the compaction approach developed by
    # General Intelligence Systems.
    # @return [LLM::Compactor]
    def compactor
      @compactor = LLM::Compactor.new(self, @compactor || {}) unless LLM::Compactor === @compactor
      @compactor
    end

    ##
    # Sets a context compactor or compactor config
    # @param [LLM::Compactor, Hash, nil] compactor
    # @return [LLM::Compactor, Hash, nil]
    def compactor=(compactor)
      @compactor = compactor
    end

    ##
    # Returns whether the context has been compacted and no later model
    # response has cleared that state.
    # @return [Boolean]
    # @api private
    attr_accessor :compacted
    alias_method :compacted?, :compacted

    ##
    # Returns a guard, if configured.
    #
    # Guards are context-level supervisors for agentic execution. A guard can
    # inspect the runtime state and decide whether pending tool work should be
    # blocked before the context keeps looping.
    #
    # The built-in implementation is {LLM::LoopGuard LLM::LoopGuard}, which
    # detects repeated tool-call patterns and turns them into in-band
    # {LLM::GuardError LLM::GuardError} tool returns.
    #
    # @return [#call, nil]
    def guard
      return if @guard.nil? || @guard == false
      @guard = LLM::LoopGuard.new if @guard == true
      @guard = LLM::LoopGuard.new(@guard) if Hash === @guard
      @guard
    end

    ##
    # Sets a guard or guard config.
    #
    # Guards must implement `call(ctx)` and return either `nil` or a warning
    # string. Returning a warning tells the context to block pending tool work
    # with guarded tool errors instead of continuing the loop.
    #
    # @param [#call, Hash, Boolean, nil] guard
    # @return [#call, Hash, Boolean, nil]
    def guard=(guard)
      @guard = guard
    end

    ##
    # Returns a transformer, if configured.
    #
    # Transformers can rewrite outgoing prompts and params before a request is
    # sent to the provider.
    #
    # @return [#call, nil]
    def transformer
      @transformer
    end

    ##
    # Sets a transformer.
    #
    # Transformers must implement `call(ctx, prompt, params)` and return a
    # two-element array of `[prompt, params]`.
    #
    # @param [#call, nil] transformer
    # @return [#call, nil]
    def transformer=(transformer)
      @transformer = transformer
    end

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
      @owner = @llm.request_owner
      compactor.compact!(prompt) if compactor.compact?(prompt)
      params = params.merge(messages: @messages.to_a)
      params = @params.merge(params)
      prompt, params = transform(prompt, params)
      bind!(params[:stream], params[:model], params[:tools])
      res = @llm.complete(prompt, params)
      self.compacted = false
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
      @owner = @llm.request_owner
      compactor.compact!(prompt) if compactor.compact?(prompt)
      params = @params.merge(params)
      prompt, params = transform(prompt, params)
      bind!(params[:stream], params[:model], params[:tools])
      res_id = params[:store] == false ? nil : @messages.find(&:assistant?)&.response&.response_id
      params = params.merge(previous_response_id: res_id, input: @messages.to_a).compact
      res = @llm.responses.create(prompt, params)
      self.compacted = false
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
    # Returns whether there is pending tool work in this context.
    # This prefers queued streamed tool work when present, and otherwise
    # falls back to unresolved functions derived from the message history.
    # @return [Boolean]
    def functions?
      pending = queue
      (pending && !pending.empty?) || functions.any?
    end

    ##
    # Spawns a function through the context.
    #
    # When a guard is configured, this method can return an in-band guarded
    # tool error instead of spawning work.
    #
    # @param [LLM::Function] function
    # @param [Symbol] strategy
    # @return [LLM::Function::Return, LLM::Function::Task]
    def spawn(function, strategy)
      warning = guard&.call(self)
      return guarded_return_for(function, warning) if warning
      function.spawn(strategy)
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
    # @param [Symbol, Array<Symbol>] strategy
    #  If the stream queue already has tool work, `wait` will drain it
    #  without using this argument.
    #  Otherwise, this controls how pending functions are resolved directly.
    #  Use `:call` for sequential execution without spawning.
    # @return [Array<LLM::Function::Return>]
    def wait(strategy)
      if LLM::Stream === stream && !stream.queue.empty?
        @queue = stream.queue
        @queue.wait
      else
        return guarded_returns if guarded_returns
        @queue = functions.spawn(strategy)
        @queue.wait
      end
    ensure
      @queue = nil
      @stream = nil
    end

    ##
    # Interrupt the active request, if any.
    # This is inspired by Go's context cancellation model.
    # @return [nil]
    def interrupt!
      pending = functions.to_a
      llm.interrupt!(@owner)
      queue&.interrupt!
      return if pending.empty?
      pending.each(&:interrupt!)
      returns = pending.map { _1.cancel(reason: "function call cancelled") }
      @messages << LLM::Message.new(@llm.tool_role, returns)
      nil
    end
    alias_method :cancel!, :interrupt!

    ##
    # Returns token usage accumulated in this context
    # @return [LLM::Object]
    def usage
      if usage = @messages.find(&:assistant?)&.usage
        LLM::Object.from(
          input_tokens: usage.input_tokens || 0,
          output_tokens: usage.output_tokens || 0,
          reasoning_tokens: usage.reasoning_tokens || 0,
          input_audio_tokens: usage.input_audio_tokens || 0,
          output_audio_tokens: usage.output_audio_tokens || 0,
          input_image_tokens: usage.input_image_tokens || 0,
          cache_read_tokens: usage.cache_read_tokens || 0,
          cache_write_tokens: usage.cache_write_tokens || 0,
          total_tokens: usage.total_tokens || 0
        )
      else
        ZERO_USAGE
      end
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
    # @return [LLM::Stream, #<<, nil]
    #  Returns a stream object, or nil
    def stream
      @stream || @params[:stream]
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
      {
        schema_version: 1,
        model:,
        compacted:,
        messages: @messages.map { serialize_message(_1) }
      }
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
      ::File.binwrite path, LLM.json.dump(to_h)
    end
    alias_method :save, :serialize

    ##
    # @return [LLM::Cost]
    #  Returns an _approximate_ cost for a given context
    #  based on both the provider, and model
    def cost
      LLM::Cost.from(self)
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

    private

    def bind!(stream, model, tools)
      return unless LLM::Stream === stream
      @stream = stream
      stream.extra[:ctx] = self
      stream.extra[:tracer] = tracer
      stream.extra[:model] = model
      stream.extra[:tools] = tools
    end

    def queue
      return @queue if @queue
      stream.queue if LLM::Stream === stream
    end

    def load_skills(skills)
      [*skills].map { LLM::Skill.load(_1).to_tool(self) }
    end

    def guarded_returns
      warning = guard&.call(self)
      return unless warning
      functions.map { guarded_return_for(_1, warning) }
    end

    def transform(prompt, params)
      return [prompt, params] unless transformer
      stream = params[:stream]
      stream.on_transform(self, transformer) if LLM::Stream === stream
      transformer.call(self, prompt, params)
    ensure
      stream.on_transform_finish(self, transformer) if LLM::Stream === stream
    end

    def guarded_return_for(function, warning)
      LLM::Function::Return.new(function.id, function.name, {
        error: true,
        type: LLM::GuardError.name,
        message: warning
      })
    end
  end

  # Backward-compatible alias
  Bot = Context

  # Scheduled for removal in v6.0
  deprecate_constant :Bot
end
