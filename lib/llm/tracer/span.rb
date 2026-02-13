# frozen_string_literal: true

require "securerandom"
require "time"

module LLM::Tracer
  ##
  # Minimal tracing primitives for eval frameworks
  class Span
    ##
    # @return [String]
    attr_reader :id, :name, :parent_id, :started_at, :ended_at, :attrs

    ##
    # @param [String, Symbol] name
    # @param [Hash] attrs
    # @param [String, nil] parent_id
    def initialize(name, attrs = {}, parent_id: nil)
      @id = SecureRandom.hex(8)
      @name = name.to_s
      @parent_id = parent_id
      @attrs = attrs.dup
      @started_at = Time.now.utc
      @start_mono = Process.clock_gettime(Process::CLOCK_MONOTONIC)
      @ended_at = nil
    end

    ##
    # @param [Hash] attrs
    # @return [LLM::Tracer::Span]
    def finish(attrs = {})
      return self if @ended_at
      @ended_at = Time.now.utc
      duration_ms = ((Process.clock_gettime(Process::CLOCK_MONOTONIC) - @start_mono) * 1000.0).round(3)
      @attrs.merge!(attrs) if attrs && !attrs.empty?
      @attrs[:duration_ms] ||= duration_ms
      self
    end

    ##
    # @return [Hash]
    def to_h
      {
        id: @id,
        name: @name,
        parent_id: @parent_id,
        started_at: @started_at.iso8601(6),
        ended_at: @ended_at&.iso8601(6),
        attrs: @attrs.dup
      }
    end
  end
end
