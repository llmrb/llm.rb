# frozen_string_literal: true

module LLM
  ##
  # The JSONAdapter class defines the interface for JSON parsers
  # that can be used by the library when dealing with JSON. The
  # following parsers are supported:
  # * {LLM::JSONAdapter::JSON LLM::JSONAdapter::JSON} (default)
  # * {LLM::JSONAdapter::Oj LLM::JSONAdapter::Oj}
  # * {LLM::JSONAdapter::Yajl LLM::JSONAdapter::Yajl}
  #
  # @example Change parser
  #   LLM.json = LLM::JSONAdapter::Oj
  class JSONAdapter
    ##
    # @return [String]
    #  Returns a JSON string representation of the given object
    def self.dump(*) = raise NotImplementedError

    ##
    # @return [Object]
    #  Returns a Ruby object parsed from the given JSON string
    def self.load(*) = raise NotImplementedError

    ##
    # @return [Exception]
    #  Returns the error raised when parsing fails
    def self.parser_error = StandardError
  end

  ##
  # The {LLM::JSONAdapter::JSON LLM::JSONAdapter::JSON} class
  # provides a JSON adapter backed by the standard library
  # JSON module.
  class JSONAdapter::JSON < JSONAdapter
    ##
    # @return (see JSONAdapter#dump)
    def self.dump(obj)
      require "json" unless defined?(::JSON)
      ::JSON.dump(obj)
    end

    ##
    # @return (see JSONAdapter#load)
    def self.load(string)
      require "json" unless defined?(::JSON)
      ::JSON.parse(string)
    end

    ##
    # @return (see JSONAdapter#parser_error)
    def self.parser_error
      require "json" unless defined?(::JSON)
      ::JSON::ParserError
    end
  end

  ##
  # The {LLM::JSONAdapter::Oj LLM::JSONAdapter::Oj} class
  # provides a JSON adapter backed by the Oj gem.
  class JSONAdapter::Oj < JSONAdapter
    ##
    # @return (see JSONAdapter#dump)
    def self.dump(obj)
      require "oj" unless defined?(::Oj)
      ::Oj.dump(obj)
    end

    ##
    # @return (see JSONAdapter#load)
    def self.load(string)
      require "oj" unless defined?(::Oj)
      ::Oj.load(string)
    end

    ##
    # @return (see JSONAdapter#parser_error)
    def self.parser_error
      require "oj" unless defined?(::Oj)
      ::Oj::ParseError
    end
  end

  ##
  # The {LLM::JSONAdapter::Yajl LLM::JSONAdapter::Yajl} class
  # provides a JSON adapter backed by the Yajl gem.
  class JSONAdapter::Yajl < JSONAdapter
    ##
    # @return (see JSONAdapter#dump)
    def self.dump(obj)
      require "yajl" unless defined?(::Yajl)
      ::Yajl::Encoder.encode(obj)
    end

    ##
    # @return (see JSONAdapter#load)
    def self.load(string)
      require "yajl" unless defined?(::Yajl)
      ::Yajl::Parser.parse(string)
    end

    ##
    # @return (see JSONAdapter#parser_error)
    def self.parser_error
      require "yajl" unless defined?(::Yajl)
      ::Yajl::ParseError
    end
  end
end
