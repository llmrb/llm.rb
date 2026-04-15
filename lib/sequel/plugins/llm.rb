# frozen_string_literal: true

module Sequel
  module Plugins
    require "llm/sequel/plugin"
    Llm = LLM::Sequel::Plugin
  end
end
