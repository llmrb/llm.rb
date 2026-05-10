# frozen_string_literal: true

class LLM::Transport
  ##
  # {LLM::Transport::StreamDecoder LLM::Transport::StreamDecoder}
  # incrementally decodes streamed HTTP response bodies into parser
  # events.
  #
  # @api private
  class StreamDecoder
    ##
    # @return [Object]
    attr_reader :parser

    ##
    # @param [#parse!, #body] parser
    # @return [LLM::Transport::StreamDecoder]
    def initialize(parser)
      @buffer = +""
      @cursor = 0
      @data = []
      @parser = parser
    end

    ##
    # @param [String] chunk
    # @return [void]
    def <<(chunk)
      @buffer << chunk
      each_line { handle_line(_1) }
    end

    ##
    # @return [Object]
    def body
      parser.body
    end

    ##
    # @return [void]
    def free
      @buffer.clear
      @cursor = 0
      @data.clear
      parser.free if parser.respond_to?(:free)
    end

    private

    def handle_line(line)
      if line == "\n" || line == "\r\n"
        flush_sse_event
      elsif line.start_with?("data:")
        @data << field_value(line)
      elsif line.start_with?("event:", "id:", "retry:", ":")
      else
        decode!(strip_newline(line))
      end
    end

    def flush_sse_event
      return if @data.empty?
      decode!(@data.join("\n"))
      @data.clear
    end

    def field_value(line)
      value_start = line.getbyte(5) == 32 ? 6 : 5
      strip_newline(line.byteslice(value_start..))
    end

    def strip_newline(line)
      line = line.byteslice(0, line.bytesize - 1) if line.end_with?("\n")
      line = line.byteslice(0, line.bytesize - 1) if line.end_with?("\r")
      line
    end

    def decode!(payload)
      return if payload.empty? || payload == "[DONE]"
      chunk = LLM.json.load(payload)
      parser.parse!(chunk) if chunk
    rescue *LLM.json.parser_error
    end

    def each_line
      while (newline = @buffer.index("\n", @cursor))
        line = @buffer[@cursor..newline]
        @cursor = newline + 1
        yield(line)
      end
      return if @cursor.zero?
      @buffer = @buffer[@cursor..] || +""
      @cursor = 0
    end
  end
end
