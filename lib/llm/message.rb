# frozen_string_literal: true

module LLM
  class Message
    ##
    # Returns the role of the message
    # @return [Symbol]
    attr_reader :role

    ##
    # Returns the content of the message
    # @return [String]
    attr_reader :content

    ##
    # Returns extra context associated with the message
    # @return [Hash]
    attr_reader :extra

    ##
    # Returns a new message
    # @param [Symbol] role
    # @param [String] content
    # @param [Hash] extra
    # @return [LLM::Message]
    def initialize(role, content, extra = {})
      @role = role.to_s
      @content = content
      @extra = extra
    end

    ##
    # Returns a hash representation of the message
    # @return [Hash]
    def to_h
      {role:, content:}
    end

    ##
    # Returns true when two objects have the same role and content
    # @param [Object] other
    #  The other object to compare
    # @return [Boolean]
    def ==(other)
      if other.respond_to?(:to_h)
        to_h == other.to_h
      else
        false
      end
    end
    alias_method :eql?, :==

    ##
    # Try to parse the content as JSON
    # @return [Hash]
    def content!
      JSON.parse(content)
    end

    ##
    # @return [Array<LLM::Function>]
    def functions
      @functions ||= tool_calls.map do |fn|
        function = tools.find { _1.name.to_s == fn["name"] }.dup
        function.tap { _1.id = fn.id }
        function.tap { _1.arguments = fn.arguments }
      end
    end

    ##
    # Marks the message as read
    # @return [void]
    def read!
      @read = true
    end

    ##
    # Returns true when the message has been read
    # @return [Boolean]
    def read?
      @read
    end

    ##
    # Returns true when the message is an assistant message
    # @return [Boolean]
    def assistant?
      role == "assistant" || role == "model"
    end

    ##
    # Returns true when the message is a system message
    # @return [Boolean]
    def system?
      role == "system"
    end

    ##
    # Returns true when the message is a user message
    # @return [Boolean]
    def user?
      role == "user"
    end

    ##
    # @return [Boolean]
    #  Returns true when the message requests a function call
    def tool_call?
      tool_calls.any?
    end

    ##
    # @return [Boolean]
    #  Returns true when the message represents a function return
    def tool_return?
      LLM::Function::Return === content ||
        [*content].grep(LLM::Function::Return).any?
    end

    ##
    # @note
    #  This method returns a response for assistant messages,
    #  and it returns nil for non-assistant messages
    # @return [LLM::Response, nil]
    #  Returns the response associated with the message, or nil
    def response
      extra[:response]
    end

    ##
    # @note
    #  This method might return annotations for assistant messages,
    #  and it returns an empty array for non-assistant messages
    # Returns annotations associated with the message
    # @return [Array<LLM::Object>]
    def annotations
      @annotations ||= LLM::Object.from_hash(extra["annotations"] || [])
    end

    ##
    # @note
    #  This method returns token usage for assistant messages,
    #  and it returns an empty object for non-assistant messages
    # Returns token usage statistics
    # @return [LLM::Object]
    def usage
      @usage ||= if response
        response.usage
      else
        LLM::Object.from_hash({})
      end
    end
    alias_method :token_usage, :usage

    ##
    # Returns a string representation of the message
    # @return [String]
    def inspect
      "#<#{self.class.name}:0x#{object_id.to_s(16)} " \
      "tool_call=#{tool_calls.any?} role=#{role.inspect} " \
      "content=#{content.inspect}>"
    end

    private

    def tool_calls
      @tool_calls ||= LLM::Object.from_hash(@extra[:tool_calls] || [])
    end

    def tools
      response&.__tools__ || []
    end
  end
end
