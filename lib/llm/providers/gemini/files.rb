# frozen_string_literal: true

class LLM::Gemini
  ##
  # The {LLM::Gemini::Files LLM::Gemini::Files} class provides a files
  # object for interacting with [Gemini's Files API](https://ai.google.dev/gemini-api/docs/files).
  # The files API allows a client to reference media files in prompts
  # where they can be referenced by their URL.
  #
  # The files API is intended to preserve bandwidth and latency,
  # especially for large files but it can be helpful for smaller files
  # as well because it does not require the client to include a file
  # in the prompt over and over again (which could be the case in a
  # multi-turn conversation).
  #
  # @example example #1
  #   #!/usr/bin/env ruby
  #   require "llm"
  #
  #   llm = LLM.gemini(key: ENV["KEY"])
  #   ses = LLM::Session.new(llm)
  #   file = llm.files.create(file: "/audio/haiku.mp3")
  #   ses.talk ["Tell me about this file", file]
  #   ses.messages.select(&:assistant?).each { print "[#{_1.role}]", _1.content, "\n" }
  class Files
    ##
    # Returns a new Files object
    # @param provider [LLM::Provider]
    # @return [LLM::Gemini::Files]
    def initialize(provider)
      @provider = provider
    end

    ##
    # List all files
    # @example
    #   llm = LLM.gemini(key: ENV["KEY"])
    #   res = llm.files.all
    #   res.each do |file|
    #     print "name: ", file.name, "\n"
    #   end
    # @see https://ai.google.dev/gemini-api/docs/files Gemini docs
    # @param [Hash] params Other parameters (see Gemini docs)
    # @raise (see LLM::Provider#request)
    # @return [LLM::Response]
    def all(**params)
      query = URI.encode_www_form(params.merge!(key: key))
      req = Net::HTTP::Get.new("/v1beta/files?#{query}", headers)
      res, span = execute(request: req, operation: "request")
      res = ResponseAdapter.adapt(res, type: :files)
      finish_trace(operation: "request", res:, span:)
    end

    ##
    # Create a file
    # @example
    #   llm = LLM.gemini(key: ENV["KEY"])
    #   res = llm.files.create(file: "/audio/haiku.mp3")
    # @see https://ai.google.dev/gemini-api/docs/files Gemini docs
    # @param [String, LLM::File] file The file
    # @param [Hash] params Other parameters (see Gemini docs)
    # @raise (see LLM::Provider#request)
    # @return [LLM::Response]
    def create(file:, **params)
      file = LLM.File(file)
      req = Net::HTTP::Post.new(request_upload_url(file:), {})
      req["content-length"] = file.bytesize
      req["X-Goog-Upload-Offset"] = 0
      req["X-Goog-Upload-Command"] = "upload, finalize"
      file.with_io do |io|
        set_body_stream(req, io)
        res, span = execute(request: req, operation: "request")
        res = ResponseAdapter.adapt(res, type: :file)
        finish_trace(operation: "request", res:, span:)
      end
    end

    ##
    # Get a file
    # @example
    #   llm = LLM.gemini(key: ENV["KEY"])
    #   res = llm.files.get(file: "files/1234567890")
    #   print "name: ", res.name, "\n"
    # @see https://ai.google.dev/gemini-api/docs/files Gemini docs
    # @param [#name, String] file The file to get
    # @param [Hash] params Other parameters (see Gemini docs)
    # @raise (see LLM::Provider#request)
    # @return [LLM::Response]
    def get(file:, **params)
      file_id = file.respond_to?(:name) ? file.name : file.to_s
      query = URI.encode_www_form(params.merge!(key: key))
      req = Net::HTTP::Get.new("/v1beta/#{file_id}?#{query}", headers)
      res, span = execute(request: req, operation: "request")
      res = ResponseAdapter.adapt(res, type: :file)
      finish_trace(operation: "request", res:, span:)
    end

    ##
    # Delete a file
    # @example
    #   llm = LLM.gemini(key: ENV["KEY"])
    #   res = llm.files.delete(file: "files/1234567890")
    # @see https://ai.google.dev/gemini-api/docs/files Gemini docs
    # @param [#name, String] file The file to delete
    # @param [Hash] params Other parameters (see Gemini docs)
    # @raise (see LLM::Provider#request)
    # @return [LLM::Response]
    def delete(file:, **params)
      file_id = file.respond_to?(:name) ? file.name : file.to_s
      query = URI.encode_www_form(params.merge!(key: key))
      req = Net::HTTP::Delete.new("/v1beta/#{file_id}?#{query}", headers)
      res, span = execute(request: req, operation: "request")
      res = LLM::Response.new(res)
      finish_trace(operation: "request", res:, span:)
    end

    ##
    # @raise [NotImplementedError]
    #  This method is not implemented by Gemini
    def download
      raise NotImplementedError
    end

    private

    include LLM::Utils

    def request_upload_url(file:)
      req = Net::HTTP::Post.new("/upload/v1beta/files?key=#{key}", headers)
      req["X-Goog-Upload-Protocol"] = "resumable"
      req["X-Goog-Upload-Command"] = "start"
      req["X-Goog-Upload-Header-Content-Length"] = file.bytesize
      req["X-Goog-Upload-Header-Content-Type"] = file.mime_type
      req.body = LLM.json.dump({file: {display_name: File.basename(file.path)}})
      res, span = execute(request: req, operation: "request")
      finish_trace(operation: "request", res: LLM::Response.new(res), span:)
      res["x-goog-upload-url"]
    end

    def key
      @provider.instance_variable_get(:@key)
    end

    [:headers, :execute, :set_body_stream, :finish_trace].each do |m|
      define_method(m) { |*args, **kwargs, &b| @provider.send(m, *args, **kwargs, &b) }
    end
  end
end
