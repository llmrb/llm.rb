# frozen_string_literal: true

##
# The {LLM::Builder LLM::Builder} class can build a collection
# of messages that can be sent in a single request.
#
# @note
# This API is not meant to be used directly.
#
# @example
#   llm = LLM.openai(key: ENV["KEY"])
#   ses = LLM::Session.new(llm)
#   prompt = ses.build_prompt do
#     it.system "Your task is to assist the user"
#     it.user "Hello. Can you assist me?"
#   end
#   res = ses.talk(prompt)
class LLM::Builder
  ##
  # @param [Proc] evaluator
  #  The evaluator
  def initialize(provider, &evaluator)
    @provider = provider
    @buffer = []
    @evaluator = evaluator
  end

  ##
  # @return [void]
  def call
    @evaluator.call(self)
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
  # @return [Array]
  def to_a
    @buffer.dup
  end
end
