# frozen_string_literal: true

require "digest"
require "openssl"

class LLM::Bedrock
  ##
  # Signs HTTP requests and headers with AWS Signature V4.
  #
  # Returns the signed headers as a Hash through #to_h, ready to merge
  # into a Net::HTTPRequest or other HTTP client. Everything else is
  # private.
  #
  # Uses only Ruby's stdlib (openssl, digest) with no external deps.
  #
  # @example
  #   signature = LLM::Bedrock::Signature.new(
  #     access_key_id: ENV["AWS_ACCESS_KEY_ID"],
  #     secret_access_key: ENV["AWS_SECRET_ACCESS_KEY"],
  #     region: "us-east-1",
  #     method: "POST",
  #     path: "/model/anthropic.claude-3/converse",
  #     body: '{"messages":[...]}',
  #     host: "bedrock-runtime.us-east-1.amazonaws.com",
  #     session_token: nil
  #   )
  #   req.merge!(signature.to_h)
  #
  # @api private
  class Signature
    SERVICE = "bedrock"

    ##
    # @param access_key_id [String] AWS access key ID
    # @param secret_access_key [String] AWS secret access key
    # @param region [String] AWS region (e.g. "us-east-1")
    # @param method [String] HTTP method ("POST", "GET", etc.)
    # @param path [String] Request path (e.g. "/model/.../converse")
    # @param body [String] Raw request body
    # @param host [String] Request host header value
    # @param session_token [String, nil] AWS session token
    def initialize(access_key_id:, secret_access_key:, region:,
                   method:, path:, body:, host:, session_token: nil)
      @access_key_id = access_key_id
      @secret_access_key = secret_access_key
      @region = region
      @method = method
      @path = path
      @body = body
      @host = host
      @session_token = session_token
    end

    ##
    # Returns the signed headers as a plain Hash.
    #
    # Call this once per request and merge the result into your
    # HTTP headers. Each call recomputes the signature with the
    # current time, so call it immediately before sending.
    #
    # @return [Hash{String => String}]
    def to_h
      now = Time.now.utc
      amz_date = now.strftime("%Y%m%dT%H%M%SZ")
      date_stamp = now.strftime("%Y%m%d")
      payload_hash = Digest::SHA256.hexdigest(@body)
      headers = {
        "X-Amz-Date" => amz_date,
        "X-Amz-Content-Sha256" => payload_hash,
        "Content-Type" => "application/json",
        "Host" => @host
      }
      headers["X-Amz-Security-Token"] = @session_token if @session_token
      signed_headers = build_signed_headers
      canonical_headers = build_canonical_headers(headers, signed_headers)
      canonical_uri = build_canonical_uri
      canonical_request = build_canonical_request(
        canonical_uri, canonical_headers, signed_headers, payload_hash
      )
      credential_scope = "#{date_stamp}/#{@region}/#{SERVICE}/aws4_request"
      string_to_sign = build_string_to_sign(
        amz_date, credential_scope, canonical_request
      )
      signing_key = derive_signing_key(date_stamp)
      signature = OpenSSL::HMAC.hexdigest(
        "sha256", signing_key, string_to_sign
      )
      headers["Authorization"] =
        "AWS4-HMAC-SHA256 " \
        "Credential=#{@access_key_id}/#{credential_scope}, " \
        "SignedHeaders=#{signed_headers}, Signature=#{signature}"
      headers
    end

    private

    def build_signed_headers
      %w[host x-amz-date x-amz-content-sha256].tap do |h|
        h << "x-amz-security-token" if @session_token
        h << "content-type"
      end.sort.join(";")
    end

    def build_canonical_headers(headers, signed_headers)
      headers = headers.transform_keys(&:downcase)
      signed_headers.split(";").map do |key|
        "#{key}:#{headers[key].to_s.strip}\n"
      end.join
    end

    def build_canonical_uri
      path = @path
      return "/" if path.nil? || path.empty?
      segments = path.split("/", -1).map { |s| uri_encode(s) }
      canonical = segments.join("/")
      canonical.start_with?("/") ? canonical : "/#{canonical}"
    end

    def build_canonical_request(uri, canonical_headers,
                                signed_headers, payload_hash)
      [
        @method,
        uri,
        "",  # canonical query string (always empty for Bedrock)
        canonical_headers,
        signed_headers,
        payload_hash
      ].join("\n")
    end

    def build_string_to_sign(amz_date, credential_scope, canonical_request)
      [
        "AWS4-HMAC-SHA256",
        amz_date,
        credential_scope,
        Digest::SHA256.hexdigest(canonical_request)
      ].join("\n")
    end

    def derive_signing_key(date_stamp)
      k_date = OpenSSL::HMAC.digest(
        "sha256", "AWS4#{@secret_access_key}", date_stamp
      )
      k_region = OpenSSL::HMAC.digest("sha256", k_date, @region)
      k_service = OpenSSL::HMAC.digest("sha256", k_region, SERVICE)
      OpenSSL::HMAC.digest("sha256", k_service, "aws4_request")
    end

    def uri_encode(str)
      URI.encode_www_form_component(str.to_s)
        .gsub("+", "%20")
        .gsub("%7E", "~")
    end
  end
end
