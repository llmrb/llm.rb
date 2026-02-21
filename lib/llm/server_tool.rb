# frozen_string_literal: true

##
# The {LLM::ServerTool LLM::ServerTool} class represents a platform-native tool
# that can be activated by an LLM provider. Unlike {LLM::Function LLM::Function},
# these tools are pre-defined by the provider and their capabilities
# are already known to the underlying LLM.
#
# @example
#   #!/usr/bin/env ruby
#   llm = LLM.gemini ENV["KEY"]
#   ses = LLM::Session.new(llm, tools: [LLM::ServerTool.new(:google_search)])
#   ses.talk("Summarize today's news", role: :user)
#   print ses.messages.find(&:assistant?).content, "\n"
class LLM::ServerTool < Struct.new(:name, :options, :provider)
  ##
  # @return [String]
  def to_json(...)
    to_h.to_json(...)
  end

  ##
  # @return [Hash]
  def to_h
    case provider.class.to_s
    when "LLM::Anthropic" then options.merge("name" => name.to_s)
    when "LLM::Gemini" then {name => options}
    else options.merge("type" => name.to_s)
    end
  end
  alias_method :to_hash, :to_h
end
