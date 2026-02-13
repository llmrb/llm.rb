# frozen_string_literal: true

require "time"

module LLM::Tracer
  class Event
    ##
    # A point-in-time event.
    # @see LLM::Tracer::Tracer
    ##
    # @return [String]
    attr_reader :name, :time, :attrs, :span_id

    ##
    # @param [String, Symbol] name
    # @param [Hash] attrs
    # @param [String, nil] span_id
    def initialize(name, attrs = {}, span_id: nil)
      @name = name.to_s
      @time = Time.now.utc
      @attrs = attrs.dup
      @span_id = span_id
    end

    ##
    # @return [Hash]
    def to_h
      {
        name: @name,
        time: @time.iso8601(6),
        span_id: @span_id,
        attrs: @attrs.dup
      }
    end
  end
end
