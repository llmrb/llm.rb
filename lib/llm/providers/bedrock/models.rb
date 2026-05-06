# frozen_string_literal: true

class LLM::Bedrock
  ##
  # The {LLM::Bedrock::Models} class provides a model object for
  # interacting with [AWS Bedrock's ListFoundationModels API](
  # https://docs.aws.amazon.com/bedrock/latest/APIReference/API_ListFoundationModels.html).
  #
  # Unlike the Converse API (which lives on `bedrock-runtime.<region>.amazonaws.com`),
  # the models endpoint lives on the control plane at
  # `bedrock.<region>.amazonaws.com`. This class manages its own HTTP
  # connection since the provider's transport is pinned to the runtime host.
  #
  # @example
  #   llm = LLM.bedrock(
  #     access_key_id: ENV["AWS_ACCESS_KEY_ID"],
  #     secret_access_key: ENV["AWS_SECRET_ACCESS_KEY"],
  #     region: "us-east-1"
  #   )
  #   llm.models.all.each { |m| puts m.id }
  class Models
    ##
    # @param [LLM::Bedrock] provider
    # @return [LLM::Bedrock::Models]
    def initialize(provider)
      @provider = provider
    end

    ##
    # List all foundation models available in the configured region.
    #
    # @note
    #  This calls AWS Bedrock's ListFoundationModels API which returns
    #  all models available in the region, not just the ones the
    #  current account is subscribed to.
    #
    # @param [Hash] params Optional query parameters
    #  (e.g. `byProvider: "Anthropic"`, `byInferenceType: "ON_DEMAND"`)
    # @return [LLM::Response]
    def all(**params)
      host = credentials.host
      handle_response http(host).request(build_request(host, params))
    end

    private

    ##
    # @param [String] host
    # @return [Net::HTTP]
    def http(host)
      http = Net::HTTP.new(host, 443)
      http.use_ssl = true
      http.read_timeout = timeout
      http
    end

    ##
    # @param [String] host
    # @param [Hash] params
    # @return [Net::HTTP::Get]
    def build_request(host, params)
      path = "/foundation-models"
      query = URI.encode_www_form(params) unless params.empty?
      path = "#{path}?#{query}" if query && !query.empty?
      body = ""
      req = Net::HTTP::Get.new(path, {"Content-Type" => "application/json", "Accept" => "application/json"})
      req.tap { sign!(req, body, host, query) }
    end

    ##
    # @param [Net::HTTPResponse] res
    # @return [LLM::Response]
    # @raise [LLM::Error]
    def handle_response(res)
      case res
      when Net::HTTPSuccess
        res.body = LLM::Object.from(LLM.json.load(res.body || "{}"))
        LLM::Bedrock::ResponseAdapter.adapt(res, type: :models)
      else
        body = +""
        res.read_body { body << _1 } if res.body.nil?
        LLM::Bedrock::ErrorHandler.new(tracer, nil, res).raise_error!
      end
    end

    ##
    # @param [Net::HTTPRequest] req
    # @param [String] body
    # @param [String] host
    # @param [String, nil] query
    # @return [Net::HTTPRequest]
    def sign!(req, body, host = credentials.host, query = nil)
      creds = credentials.tap { _1.host = host }
      Signature.new(credentials: creds, method: "GET", path: "/foundation-models", query:, body:).sign!(req)
    end

    ##
    # @return [LLM::Object]
    def credentials
      LLM::Object.from(@provider.send(:credentials).to_h).tap do
        _1.host = "bedrock.#{_1.aws_region}.amazonaws.com"
      end
    end

    [:timeout, :tracer].each do |m|
      define_method(m) { @provider.send(m) }
    end
  end
end
