# frozen_string_literal: true

##
# {LLM::Prompt LLM::Prompt} is a small object for composing
# a single request from multiple role-aware messages.
#
# A prompt is not just a string. It is an ordered chain of
# messages with explicit roles (for example +system+ and +user+).
#
# Use {LLM::Session#prompt} when building a prompt inside a session.
# Use +LLM::Prompt.new(provider)+ directly when you want to construct
# or pass prompt objects around explicitly.
#
# @example
#   llm = LLM.openai(key: ENV["KEY"])
#   ses = LLM::Session.new(llm)
#   prompt = ses.prompt do
#     system "Your task is to assist the user"
#     user "Hello. Can you assist me?"
#   end
#   res = ses.talk(prompt)
class LLM::Prompt
  ##
  # @param [LLM::Provider] provider
  #  A provider used to resolve provider-specific role names.
  # @param [Proc] b
  #  A block that composes messages. If the block takes one argument,
  #  it receives the prompt object. Otherwise the block runs in the
  #  prompt context via +instance_eval+.
  def initialize(provider, &b)
    @provider = provider
    @buffer = []
    unless b.nil?
      (b.arity == 1) ? b.call(self) : instance_eval(&b)
    end
  end

  ##
  # @param [String] content
  #  The message
  # @param [Symbol] role
  #  The role (eg user, system)
  # @return [void]
  def talk(content, role: @provider.user_role)
    role = case role.to_sym
    when :system then @provider.system_role
    when :user then @provider.user_role
    when :developer then @provider.developer_role
    else role
    end
    @buffer << LLM::Message.new(role, content)
  end
  alias_method :chat, :talk

  ##
  # @param [String] content
  #  The message content
  # @return [void]
  def user(content)
    chat(content, role: @provider.user_role)
  end

  ##
  # @param [String] content
  #  The message content
  # @return [void]
  def system(content)
    chat(content, role: @provider.system_role)
  end

  ##
  # @param [String] content
  #  The message content
  # @return [void]
  def developer(content)
    chat(content, role: @provider.developer_role)
  end

  ##
  # @return [Array<LLM::Message>]
  #  Returns the prompt messages in order.
  def to_a
    @buffer.dup
  end
end
