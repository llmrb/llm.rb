# frozen_string_literal: true

class LLM::OpenAI
  ##
  # The {LLM::OpenAI::Images LLM::OpenAI::Images} class provides an interface
  # for [OpenAI's images API](https://platform.openai.com/docs/api-reference/images).
  # OpenAI supports multiple response formats: temporary URLs, or binary strings
  # encoded in base64. The default is to return base64-encoded image data.
  #
  # @example Temporary URLs
  #   #!/usr/bin/env ruby
  #   require "llm"
  #   require "open-uri"
  #   require "fileutils"
  #
  #   llm = LLM.openai(key: ENV["KEY"])
  #   res = llm.images.create prompt: "A dog on a rocket to the moon",
  #                           response_format: "url"
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
    #   IO.copy_stream res.images[0], "rocket.png"
    # @see https://platform.openai.com/docs/api-reference/images/create OpenAI docs
    # @param [String] prompt The prompt
    # @param [String] model The model to use
    # @param [String] response_format The response format ("b64_json" or "url")
    # @param [Hash] params Other parameters (see OpenAI docs)
    # @raise (see LLM::Provider#request)
    # @return [LLM::Response]
    def create(prompt:, model: "dall-e-3", response_format: "b64_json", **params)
      req = Net::HTTP::Post.new(path("/images/generations"), headers)
      req.body = LLM.json.dump({prompt:, n: 1, model:, response_format:}.merge!(params))
      res, span, tracer = execute(request: req, operation: "request")
      res = ResponseAdapter.adapt(res, type: :image)
      tracer.on_request_finish(operation: "request", model:, res:, span:)
      res
    end

    ##
    # Create image variations
    # @example
    #   llm = LLM.openai(key: ENV["KEY"])
    #   res = llm.images.create_variation(image: "/images/hat.png", n: 5)
    #   res.images.each.with_index do |image, index|
    #     IO.copy_stream image, "variation#{index}.png"
    #   end
    # @see https://platform.openai.com/docs/api-reference/images/createVariation OpenAI docs
    # @param [File] image The image to create variations from
    # @param [String] model The model to use
    # @param [String] response_format The response format ("b64_json" or "url")
    # @param [Hash] params Other parameters (see OpenAI docs)
    # @raise (see LLM::Provider#request)
    # @return [LLM::Response]
    def create_variation(image:, model: "dall-e-2", response_format: "b64_json", **params)
      image = LLM.File(image)
      multi = LLM::Multipart.new(params.merge!(image:, model:, response_format:))
      req = Net::HTTP::Post.new(path("/images/variations"), headers)
      req["content-type"] = multi.content_type
      transport.set_body_stream(req, multi.body)
      res, span, tracer = execute(request: req, operation: "request")
      res = ResponseAdapter.adapt(res, type: :image)
      tracer.on_request_finish(operation: "request", model:, res:, span:)
      res
    end

    ##
    # Edit an image
    # @example
    #   llm = LLM.openai(key: ENV["KEY"])
    #   res = llm.images.edit(image: "/images/hat.png", prompt: "A cat wearing this hat")
    #   IO.copy_stream res.images[0], "hatoncat.png"
    # @see https://platform.openai.com/docs/api-reference/images/createEdit OpenAI docs
    # @param [File] image The image to edit
    # @param [String] prompt The prompt
    # @param [String] model The model to use
    # @param [String] response_format The response format ("b64_json" or "url")
    # @param [Hash] params Other parameters (see OpenAI docs)
    # @raise (see LLM::Provider#request)
    # @return [LLM::Response]
    def edit(image:, prompt:, model: "dall-e-2", response_format: "b64_json", **params)
      image = LLM.File(image)
      multi = LLM::Multipart.new(params.merge!(image:, prompt:, model:, response_format:))
      req = Net::HTTP::Post.new(path("/images/edits"), headers)
      req["content-type"] = multi.content_type
      transport.set_body_stream(req, multi.body)
      res, span, tracer = execute(request: req, operation: "request")
      res = ResponseAdapter.adapt(res, type: :image)
      tracer.on_request_finish(operation: "request", model:, res:, span:)
      res
    end

    private

    [:path, :headers, :execute, :transport].each do |m|
      define_method(m) { |*args, **kwargs, &b| @provider.send(m, *args, **kwargs, &b) }
    end
  end
end
