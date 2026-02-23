# frozen_string_literal: true

module LLM
  ##
  # {LLM::Buffer LLM::Buffer} provides an Enumerable object that
  # tracks messages in a conversation thread.
  class Buffer
    include Enumerable

    ##
    # @param [LLM::Provider] provider
    # @return [LLM::Buffer]
    def initialize(provider)
      @provider = provider
      @messages = []
    end

    ##
    # Append an array
    # @param [Array<LLM::Message>] ary
    #  The array to append
    def concat(ary)
      @messages.concat(ary)
    end

    ##
    # @yield [LLM::Message]
    #  Yields each message in the conversation thread
    # @return [void]
    def each(...)
      if block_given?
        @messages.each { yield(_1) }
      else
        enum_for(:each, ...)
      end
    end

    ##
    # Find a message (in descending order)
    # @return [LLM::Message, nil]
    def find(...)
      reverse_each.find(...)
    end

    ##
    # Returns the last message(s) in the buffer
    # @param [Integer, nil] n
    #  The number of messages to return
    # @return [LLM::Message, Array<LLM::Message>, nil]
    def last(n = nil)
      n.nil? ? @messages.last : @messages.last(n)
    end

    ##
    # @param [[LLM::Message]] item
    #  A message to add to the buffer
    # @return [void]
    def <<(item)
      @messages << item
      self
    end
    alias_method :push, :<<

    ##
    # @param [Integer, Range] index
    #  The message index
    # @return [LLM::Message, nil]
    #  Returns a message, or nil
    def [](index)
      @messages[index]
    end

    ##
    # @return [String]
    def to_json(...)
      LLM.json.dump(@messages, ...)
    end

    ##
    # @return [String]
    def inspect
      "#<#{self.class.name}:0x#{object_id.to_s(16)} " \
      "message_count=#{@messages.size}>"
    end

    ##
    # Returns true when the buffer is empty
    # @return [Boolean]
    def empty?
      @messages.empty?
    end
  end
end
