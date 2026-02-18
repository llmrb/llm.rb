# frozen_string_literal: true

require "setup"
require "llm/providers/openai"

RSpec.describe LLM::OpenAI::ErrorHandler do
  subject(:handler) { described_class.new(tracer, span, response) }
  let(:tracer) { LLM::Tracer::Null.new(nil) }
  let(:span) { nil }

  context "when response is a server error" do
    let(:response) { Net::HTTPServerError.new("1.1", "500", "Internal Server Error") }
    before { allow(response).to receive(:body).and_return("{}") }

    it "raises LLM::ServerError" do
      expect { handler.raise_error! }.to raise_error(LLM::ServerError)
    end
  end

  context "when response is unauthorized" do
    let(:response) { Net::HTTPUnauthorized.new("1.1", "401", "Unauthorized") }
    before { allow(response).to receive(:body).and_return("{}") }

    it "raises LLM::UnauthorizedError" do
      expect { handler.raise_error! }.to raise_error(LLM::UnauthorizedError)
    end
  end

  context "when response is rate limited" do
    let(:response) { Net::HTTPTooManyRequests.new("1.1", "429", "Too Many Requests") }
    before { allow(response).to receive(:body).and_return("{}") }

    it "raises LLM::RateLimitError" do
      expect { handler.raise_error! }.to raise_error(LLM::RateLimitError)
    end
  end

  context "when response is invalid request error" do
    let(:response) { Net::HTTPBadRequest.new("1.1", "400", "Bad Request") }
    let(:body) { '{"error":{"type":"invalid_request_error","message":"Bad request","code":"bad_request"}}' }

    before { allow(response).to receive(:body).and_return(body) }

    it "raises LLM::InvalidRequestError" do
      expect { handler.raise_error! }.to raise_error(LLM::InvalidRequestError)
    end
  end

  context "when response is context window exceeded" do
    let(:response) { Net::HTTPBadRequest.new("1.1", "400", "Bad Request") }
    let(:body) { '{"error":{"type":"invalid_request_error","message":"Context window exceeded","code":"context_length_exceeded"}}' }

    before { allow(response).to receive(:body).and_return(body) }

    it "raises LLM::ContextWindowError" do
      expect { handler.raise_error! }.to raise_error(LLM::ContextWindowError)
    end
  end

  context "when response is unknown error type" do
    let(:response) { Net::HTTPResponse.new("1.1", "400", "Bad Request") }
    let(:body) { '{"error":{"type":"unknown_error","message":"Something went wrong"}}' }

    before { allow(response).to receive(:body).and_return(body) }

    it "raises LLM::Error" do
      expect { handler.raise_error! }.to raise_error(LLM::Error)
    end
  end
end
