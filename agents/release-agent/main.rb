# frozen_string_literal: true

require_relative "../release-agent"

def main(_argv)
  print "target: "
  version = gets.chomp
  version = "v#{version}" unless version[0] == "v"
  print "Does #{version} look right to you [y/n]: "
  if gets.chomp.downcase[0] == "y"
    llm = LLM.deepseek(key: ENV["DEEPSEEK_SECRET"])
    ReleaseAgent.new(llm).release!(version:)
  else
    puts "Aborted at user's request"
  end
end

main(ARGV) if $PROGRAM_NAME == __FILE__
