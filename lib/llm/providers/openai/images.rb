# frozen_string_literal: true

class LLM::OpenAI
  ##
  # The {LLM::OpenAI::Images LLM::OpenAI::Images} class provides an interface
  # for [OpenAI's images API](https://platform.openai.com/docs/api-reference/images).
  # OpenAI supports multiple response formats: temporary URLs, or binary strings
  # encoded in base64. The default is to return temporary URLs.
  #
  # @example Temporary URLs
  #   #!/usr/bin/env ruby
  #   require "llm"
  #   require "open-uri"
  #   require "fileutils"
  #
  #   llm = LLM.openai(key: ENV["KEY"])
  #   res = llm.images.create prompt: "A dog on a rocket to the moon"
  #   FileUtils.mv OpenURI.open_uri(res.urls[0]).path,
  #                "rocket.png"
  #
  # @example Binary strings
  #   #!/usr/bin/env ruby
  #   require "llm"
  #
  #   llm = LLM.openai(key: ENV["KEY"])
  #   res = llm.images.create prompt: "A dog on a rocket to the moon",
  #                           response_format: "b64_json"
  #   IO.copy_stream res.images[0], "rocket.png"
  class Images
    ##
    # Returns a new Images object
    # @param provider [LLM::Provider]
    # @return [LLM::OpenAI::Responses]
    def initialize(provider)
      @provider = provider
    end

    ##
    # Create an image
    # @example
    #   llm = LLM.openai(key: ENV["KEY"])
    #   res = llm.images.create prompt: "A dog on a rocket to the moon"
    #   res.urls.each { print _1, "\n" }
    # @see https://platform.openai.com/docs/api-reference/images/create OpenAI docs
    # @param [String] prompt The prompt
    # @param [String] model The model to use
    # @param [Hash] params Other parameters (see OpenAI docs)
    # @raise (see LLM::Provider#request)
    # @return [LLM::Response]
    def create(prompt:, model: "dall-e-3", **params)
      req = Net::HTTP::Post.new("/v1/images/generations", headers)
      req.body = LLM.json.dump({prompt:, n: 1, model:}.merge!(params))
      res, span = execute(request: req, operation: "request")
      res = ResponseAdapter.adapt(res, type: :image)
      finish_trace(operation: "request", model:, res:, span:)
    end

    ##
    # Create image variations
    # @example
    #   llm = LLM.openai(key: ENV["KEY"])
    #   res = llm.images.create_variation(image: "/images/hat.png", n: 5)
    #   p res.urls
    # @see https://platform.openai.com/docs/api-reference/images/createVariation OpenAI docs
    # @param [File] image The image to create variations from
    # @param [String] model The model to use
    # @param [Hash] params Other parameters (see OpenAI docs)
    # @raise (see LLM::Provider#request)
    # @return [LLM::Response]
    def create_variation(image:, model: "dall-e-2", **params)
      image = LLM.File(image)
      multi = LLM::Multipart.new(params.merge!(image:, model:))
      req = Net::HTTP::Post.new("/v1/images/variations", headers)
      req["content-type"] = multi.content_type
      set_body_stream(req, multi.body)
      res, span = execute(request: req, operation: "request")
      res = ResponseAdapter.adapt(res, type: :image)
      finish_trace(operation: "request", model:, res:, span:)
    end

    ##
    # Edit an image
    # @example
    #   llm = LLM.openai(key: ENV["KEY"])
    #   res = llm.images.edit(image: "/images/hat.png", prompt: "A cat wearing this hat")
    #   p res.urls
    # @see https://platform.openai.com/docs/api-reference/images/createEdit OpenAI docs
    # @param [File] image The image to edit
    # @param [String] prompt The prompt
    # @param [String] model The model to use
    # @param [Hash] params Other parameters (see OpenAI docs)
    # @raise (see LLM::Provider#request)
    # @return [LLM::Response]
    def edit(image:, prompt:, model: "dall-e-2", **params)
      image = LLM.File(image)
      multi = LLM::Multipart.new(params.merge!(image:, prompt:, model:))
      req = Net::HTTP::Post.new("/v1/images/edits", headers)
      req["content-type"] = multi.content_type
      set_body_stream(req, multi.body)
      res, span = execute(request: req, operation: "request")
      res = ResponseAdapter.adapt(res, type: :image)
      finish_trace(operation: "request", model:, res:, span:)
    end

    private

    [:headers, :execute, :set_body_stream, :finish_trace].each do |m|
      define_method(m) { |*args, **kwargs, &b| @provider.send(m, *args, **kwargs, &b) }
    end
  end
end
