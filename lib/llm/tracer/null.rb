# frozen_string_literal: true

module LLM::Tracer
  ##
  # A no-op tracer that discards spans and events.
  class Null
    ##
    # @return [nil]
    def start_span(*) = nil

    ##
    # @return [nil]
    def end_span(*) = nil

    ##
    # @return [nil]
    def event(*) = nil
      
    ##
    # @return [nil]
    def error(*) = nil

    ##
    # @yield [span] Yields nil
    # @return [void]
    def with_span(*)
      yield(nil)
    end
  end
end
