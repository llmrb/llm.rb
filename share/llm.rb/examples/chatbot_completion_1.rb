#!/usr/bin/env ruby
require "bundler/setup"
require_relative "../../../spec/setup"

##
# variables
cassette = "openai/readme/chat_completion_1"

##
# functions
def example
  llm  = LLM.openai(key: ENV["KEY"])
  bot  = LLM::Bot.new(llm)
  msgs = bot.chat do |prompt|
    prompt.system File.read("./share/llm/prompts/system.txt")
    prompt.user "Tell me the answer to 5 + 15"
    prompt.user "Tell me the answer to (5 + 15) * 2"
    prompt.user "Tell me the answer to ((5 + 15) * 2) / 10"
  end
  msgs.each { print "[#{_1.role}] ", _1.content, "\n" }
end

##
# main
VCR.use_cassette(cassette, record: :once) { example }
