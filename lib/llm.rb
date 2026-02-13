# frozen_string_literal: true

module LLM
  require "stringio"
  require_relative "llm/tracer"
  require_relative "llm/json_adapter"
  require_relative "llm/error"
  require_relative "llm/contract"
  require_relative "llm/usage"
  require_relative "llm/builder"
  require_relative "llm/schema"
  require_relative "llm/object"
  require_relative "llm/version"
  require_relative "llm/utils"
  require_relative "llm/message"
  require_relative "llm/response"
  require_relative "llm/mime"
  require_relative "llm/multipart"
  require_relative "llm/file"
  require_relative "llm/provider"
  require_relative "llm/bot"
  require_relative "llm/buffer"
  require_relative "llm/function"
  require_relative "llm/eventstream"
  require_relative "llm/eventhandler"
  require_relative "llm/tool"
  require_relative "llm/server_tool"

  ##
  # Thread-safe monitors for different contexts
  @monitors = {require: Monitor.new, clients: Monitor.new, inherited: Monitor.new}

  module_function

  ##
  # Returns the JSON adapter used by the library
  # @return [Class]
  #  Returns a class that responds to +dump+ and +load+
  def json
    @json ||= JSONAdapter::JSON
  end

  ##
  # Sets the JSON adapter used by the library
  # @note
  #  This should be set once from the main thread when your program starts.
  #  Defaults to {LLM::JSONAdapter::JSON LLM::JSONAdapter::JSON}.
  # @param [Class, String, Symbol] adapter
  #  A JSON adapter class or its name
  # @return [void]
  def json=(adapter)
    @json = case adapter.to_s
    when "JSON", "json" then JSONAdapter::JSON
    when "Oj", "oj" then JSONAdapter::Oj
    when "Yajl", "yajl" then JSONAdapter::Yajl
    else
      is_class = Class === adapter
      is_subclass = is_class && adapter.ancestors.include?(LLM::JSONAdapter)
      if is_subclass
        adapter
      else
        raise TypeError, "Adapter must be a subclass of LLM::JSONAdapter"
      end
    end
  end

  ##
  # @param (see LLM::Provider#initialize)
  # @return (see LLM::Anthropic#initialize)
  def anthropic(**)
    lock(:require) { require_relative "llm/providers/anthropic" unless defined?(LLM::Anthropic) }
    LLM::Anthropic.new(**)
  end

  ##
  # @param (see LLM::Provider#initialize)
  # @return (see LLM::Gemini#initialize)
  def gemini(**)
    lock(:require) { require_relative "llm/providers/gemini" unless defined?(LLM::Gemini) }
    LLM::Gemini.new(**)
  end

  ##
  # @param key (see LLM::Provider#initialize)
  # @return (see LLM::Ollama#initialize)
  def ollama(key: nil, **)
    lock(:require) { require_relative "llm/providers/ollama" unless defined?(LLM::Ollama) }
    LLM::Ollama.new(key:, **)
  end

  ##
  # @param key (see LLM::Provider#initialize)
  # @return (see LLM::LlamaCpp#initialize)
  def llamacpp(key: nil, **)
    lock(:require) { require_relative "llm/providers/llamacpp" unless defined?(LLM::LlamaCpp) }
    LLM::LlamaCpp.new(key:, **)
  end

  ##
  # @param key (see LLM::Provider#initialize)
  # @return (see LLM::DeepSeek#initialize)
  def deepseek(**)
    lock(:require) { require_relative "llm/providers/deepseek" unless defined?(LLM::DeepSeek) }
    LLM::DeepSeek.new(**)
  end

  ##
  # @param key (see LLM::Provider#initialize)
  # @return (see LLM::OpenAI#initialize)
  def openai(**)
    lock(:require) { require_relative "llm/providers/openai" unless defined?(LLM::OpenAI) }
    LLM::OpenAI.new(**)
  end

  ##
  # @param key (see LLM::XAI#initialize)
  # @param host (see LLM::XAI#initialize)
  # @return (see LLM::XAI#initialize)
  def xai(**)
    lock(:require) { require_relative "llm/providers/xai" unless defined?(LLM::XAI) }
    LLM::XAI.new(**)
  end

  ##
  # @param key (see LLM::ZAI#initialize)
  # @param host (see LLM::ZAI#initialize)
  # @return (see LLM::ZAI#initialize)
  def zai(**)
    lock(:require) { require_relative "llm/providers/zai" unless defined?(LLM::ZAI) }
    LLM::ZAI.new(**)
  end

  ##
  # Define a function
  # @example
  #   LLM.function(:system) do |fn|
  #     fn.description "Run system command"
  #     fn.params do |schema|
  #       schema.object(command: schema.string.required)
  #     end
  #     fn.define do |command:|
  #       system(command)
  #     end
  #   end
  # @param [Symbol] key The function name / key
  # @param [Proc] b The block to define the function
  # @return [LLM::Function] The function object
  def function(key, &b)
    LLM::Function.new(key, &b)
  end

  ##
  # Provides a thread-safe lock
  # @param [Symbol] name The name of the lock
  # @param [Proc] & The block to execute within the lock
  # @return [void]
  def lock(name, &) = @monitors[name].synchronize(&)
end
