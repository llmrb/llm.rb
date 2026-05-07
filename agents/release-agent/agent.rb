# frozen_string_literal: true

require "llm"
require "test/cmd"
require_relative "stream"
Dir[File.join(__dir__, "tools", "*.rb")].sort.each { require(_1) }

class ReleaseAgent < LLM::Agent
  skills File.join(__dir__, "skills", "release")
  concurrency :thread

  def initialize(llm, params = {})
    super(llm, {stream: Stream.new}.merge(params))
  end

  def release!(version:)
    talk("Prepare the release for llm.rb #{version}")
  end
end
