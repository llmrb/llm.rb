# frozen_string_literal: true

class LLM::Transport
  ##
  # Internal request execution methods for {LLM::Provider}.
  #
  # This module handles provider-side transport execution, response
  # parsing, streaming, and request body setup.
  #
  # @api private
  module Execution
    private

    ##
    # Executes a HTTP request
    # @param [Net::HTTPRequest] request
    #  The request to send
    # @param [Proc] b
    #  A block to yield the response to (optional)
    # @return [LLM::Transport::Response]
    #  The response from the server
    # @raise [LLM::Error::Unauthorized]
    #  When authentication fails
    # @raise [LLM::Error::RateLimit]
    #  When the rate limit is exceeded
    # @raise [LLM::Error]
    #  When any other unsuccessful status code is returned
    # @raise [SystemCallError]
    #  When there is a network error at the operating system level
    # @return [LLM::Transport::Response]
    def execute(request:, operation:, stream: nil, stream_parser: self.stream_parser, model: nil, inputs: nil, &b)
      owner = transport.request_owner
      tracer = self.tracer
      span = tracer.on_request_start(operation:, model:, inputs:)
      res = transport.request(request, owner:, stream:, stream_parser:, stream_decoder:, &b)
      res = LLM::Transport::Response.from(res)
      [handle_response(res, tracer, span), span, tracer]
    rescue *transport.interrupt_errors
      raise LLM::Interrupt, "request interrupted" if transport.interrupted?(owner)
      raise
    end

    ##
    # Handles the response from a request
    # @param [LLM::Transport::Response] res
    #  The response to handle
    # @param [Object, nil] span
    #  The span
    # @return [LLM::Transport::Response]
    def handle_response(res, tracer, span)
      res.ok? ? res.body = parse_response(res) : error_handler.new(tracer, span, res).raise_error!
      res
    end

    ##
    # Parse a HTTP response
    # @param [LLM::Transport::Response] res
    # @return [LLM::Object, String]
    def parse_response(res)
      case res["content-type"]
      when %r{\Aapplication/json\s*} then LLM::Object.from(LLM.json.load(res.body))
      else res.body
      end
    end

    ##
    # @param [Net::HTTPRequest] req
    #  The request to set the body stream for
    # @param [IO] io
    #  The IO object to set as the body stream
    # @return [void]
    def set_body_stream(req, io)
      req.body_stream = io
      req["transfer-encoding"] = "chunked" unless req["content-length"]
    end
  end
end
