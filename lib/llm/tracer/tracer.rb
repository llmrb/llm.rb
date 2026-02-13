# frozen_string_literal: true

module LLM::Tracer
  ##
  # A simple in-memory tracer for prototyping.
  class Tracer
    ##
    # @return [Array<LLM::Tracer::Span>]
    attr_reader :spans, :events

    ##
    # @return [LLM::Tracer::Tracer]
    def initialize
      @spans = []
      @events = []
    end

    ##
    # Start a span and set it as current in this thread.
    # @param [String, Symbol] name
    # @param [Hash] attrs
    # @return [LLM::Tracer::Span]
    def start_span(name, attrs = {})
      span = Span.new(name, attrs, parent_id: current_span&.id)
      @spans << span
      stack << span
      span
    end

    ##
    # End a span.
    # @param [LLM::Tracer::Span, nil] span
    # @param [Hash] attrs
    # @return [LLM::Tracer::Span, nil]
    def end_span(span = nil, attrs = {})
      span ||= current_span
      return unless span
      span.finish(attrs)
      stack.pop if stack.last == span
      span
    end

    ##
    # Record a point-in-time event.
    # @param [String, Symbol] name
    # @param [Hash] attrs
    # @return [LLM::Tracer::Event]
    def event(name, attrs = {})
      @events << Event.new(name, attrs, span_id: current_span&.id)
    end

    ##
    # Record an error event.
    # @param [Exception] err
    # @param [Hash] attrs
    # @return [LLM::Tracer::Event]
    def error(err, attrs = {})
      event("error", {
        error: {class: err.class.name, message: err.message}
      }.merge(attrs))
    end

    ##
    # Start a span, yield it, then end the span.
    # @param [String, Symbol] name
    # @param [Hash] attrs
    # @yield [span] The new span
    # @return [void]
    def with_span(name, attrs = {})
      span = start_span(name, attrs)
      yield(span)
    ensure
      end_span(span)
    end

    ##
    # Serialize spans and events.
    # @return [Hash]
    def to_h
      {spans: @spans.map(&:to_h), events: @events.map(&:to_h)}
    end

    private

    def stack
      Thread.current[stack_key] ||= []
    end

    def current_span
      stack.last
    end

    def stack_key
      @stack_key ||= :"llm.tracer.stack.#{object_id}"
    end
  end
end
