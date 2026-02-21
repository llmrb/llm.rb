# frozen_string_literal: true

module LLM
  ##
  # {LLM::Session LLM::Session} provides an object that can maintain a
  # conversation. A conversation can use the chat completions API
  # that all LLM providers support or the responses API that currently
  # only OpenAI supports.
  #
  # @example
  #   #!/usr/bin/env ruby
  #   require "llm"
  #
  #   llm = LLM.openai(key: ENV["KEY"])
  #   ses = LLM::Session.new(llm)
  #   prompt = ses.build_prompt do
  #     it.system "Be concise and show your reasoning briefly."
  #     it.user "If a train goes 60 mph for 1.5 hours, how far does it travel?"
  #     it.user "Now double the speed for the same time."
  #   end
  #   res = ses.talk(prompt)
  #   res.messages.each { |m| puts "[#{m.role}] #{m.content}" }
  class Session
    ##
    # Returns an Enumerable for the messages in a conversation
    # @return [LLM::Buffer<LLM::Message>]
    attr_reader :messages

    ##
    # @param [LLM::Provider] provider
    #  A provider
    # @param [Hash] params
    #  The parameters to maintain throughout the conversation.
    #  Any parameter the provider supports can be included and
    #  not only those listed here.
    # @option params [String] :model Defaults to the provider's default model
    # @option params [Array<LLM::Function>, nil] :tools Defaults to nil
    def initialize(provider, params = {})
      @provider = provider
      @params = {model: provider.default_model, schema: nil}.compact.merge!(params)
      @messages = LLM::Buffer.new(provider)
    end

    ##
    # Maintain a conversation via the chat completions API.
    # This method immediately sends a request to the LLM and returns the response.
    #
    # @param prompt (see LLM::Provider#complete)
    # @param params The params, including optional :role (defaults to :user), :stream, :tools, :schema etc.
    # @return [LLM::Response] Returns the LLM's response for this turn.
    # @example
    #   llm = LLM.openai(key: ENV["KEY"])
    #   ses = LLM::Session.new(llm)
    #   response = ses.talk("Hello, what is your name?")
    #   puts response.choices[0].content
    def talk(prompt, params = {})
      prompt, params, messages = fetch(prompt, params)
      params = params.merge(messages: [*@messages.to_a, *messages])
      params = @params.merge(params)
      res = @provider.complete(prompt, params)
      @messages.concat [LLM::Message.new(params[:role] || :user, prompt)]
      @messages.concat messages
      @messages.concat [res.choices[-1]]
      res
    end
    alias_method :chat, :talk

    ##
    # Maintain a conversation via the responses API.
    # This method immediately sends a request to the LLM and returns the response.
    #
    # @note Not all LLM providers support this API
    # @param prompt (see LLM::Provider#complete)
    # @param params The params, including optional :role (defaults to :user), :stream, :tools, :schema etc.
    # @return [LLM::Response] Returns the LLM's response for this turn.
    # @example
    #   llm = LLM.openai(key: ENV["KEY"])
    #   ses = LLM::Session.new(llm)
    #   res = ses.respond("What is the capital of France?")
    #   puts res.output_text
    def respond(prompt, params = {})
      prompt, params, messages = fetch(prompt, params)
      res_id = @messages.find(&:assistant?)&.response&.response_id
      params = params.merge(previous_response_id: res_id, input: messages).compact
      params = @params.merge(params)
      res = @provider.responses.create(prompt, params)
      @messages.concat [LLM::Message.new(params[:role] || :user, prompt)]
      @messages.concat messages
      @messages.concat [res.choices[-1]]
      res
    end

    ##
    # @return [String]
    def inspect
      "#<#{self.class.name}:0x#{object_id.to_s(16)} " \
      "@provider=#{@provider.class}, @params=#{@params.inspect}, " \
      "@messages=#{@messages.inspect}>"
    end

    ##
    # Returns an array of functions that can be called
    # @return [Array<LLM::Function>]
    def functions
      @messages
        .select(&:assistant?)
        .flat_map do |msg|
          fns = msg.functions.select(&:pending?)
          fns.each do |fn|
            fn.tracer = tracer
            fn.model  = msg.model
          end
        end
    end

    ##
    # Returns token usage for the conversation
    # @note
    # This method returns token usage for the latest
    # assistant message, and it returns an empty object
    # if there are no assistant messages
    # @return [LLM::Object]
    def usage
      @messages.find(&:assistant?)&.usage || LLM::Object.from({})
    end

    ##
    # Build a prompt
    # @example
    #   prompt = ses.build_prompt do
    #     it.system "Your task is to assist the user"
    #     it.user "Hello, can you assist me?"
    #   end
    #   ses.talk(prompt)
    def build_prompt(&)
      LLM::Builder.new(@provider, &).tap(&:call)
    end

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
      @provider.tracer
    end

    ##
    # Returns the model a Session is actively using
    # @return [String]
    def model
      messages.find(&:assistant?)&.model || @params[:model]
    end

    private

    def fetch(prompt, params)
      return [prompt, params, []] unless LLM::Builder === prompt
      messages = prompt.to_a
      prompt = messages.shift
      params.merge!(role: prompt.role)
      [prompt.content, params, messages]
    end
  end

  # Backward-compatible alias
  Bot = Session
end
