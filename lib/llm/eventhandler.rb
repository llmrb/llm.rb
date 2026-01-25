# frozen_string_literal: true

module LLM
  ##
  # @private
  class EventHandler
    ##
    # @param [#parse!] parser
    # @return [LLM::EventHandler]
    def initialize(parser)
      @parser = parser
    end

    ##
    # "data:" event callback
    # @param [LLM::EventStream::Event] event
    # @return [void]
    def on_data(event)
      return if event.end?
      chunk = LLM.json.load(event.value)
      return unless chunk
      @parser.parse!(chunk)
    rescue *LLM.json.parser_error
    end

    ##
    # Callback for when *any* of chunk of data
    # is received, regardless of whether it has
    # a field name or not. Primarily for ollama,
    # which does emit Server-Sent Events (SSE).
    # @param [LLM::EventStream::Event] event
    # @return [void]
    def on_chunk(event)
      return if event.end?
      chunk = LLM.json.load(event.chunk)
      return unless chunk
      @parser.parse!(chunk)
    rescue *LLM.json.parser_error
    end

    ##
    # Returns a fully constructed response body
    # @return [LLM::Object]
    def body = @parser.body
  end
end
