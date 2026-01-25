# frozen_string_literal: true

require "llm"
require "webmock/rspec"
require "vcr"
require "dotenv"

Dir[File.join(__dir__, "support/shared_examples/*.rb")].each { require(_1) }
Dotenv.load

LLM.json = ENV.fetch("JSON_PARSER", "JSON")

RSpec.configure do |config|
  config.disable_monkey_patching!

  config.expect_with :rspec do |c|
    c.syntax = :expect
  end
end

VCR.configure do |config|
  config.cassette_library_dir = "spec/fixtures/cassettes"
  config.hook_into :webmock
  config.configure_rspec_metadata!

  ##
  # scrub
  config.filter_sensitive_data("TOKEN") { ENV["ANTHROPIC_SECRET"] }
  config.filter_sensitive_data("TOKEN") { ENV["GEMINI_SECRET"] }
  config.filter_sensitive_data("TOKEN") { ENV["OPENAI_SECRET"] }
  config.filter_sensitive_data("TOKEN") { ENV["DEEPSEEK_SECRET"] }
  config.filter_sensitive_data("TOKEN") { ENV["XAI_SECRET"] }
  config.filter_sensitive_data("TOKEN") { ENV["ZAI_SECRET"] }
  config.filter_sensitive_data("localhost") { ENV["OLLAMA_HOST"] }

  config.before_record do
    body = _1.response.body
    body.gsub! %r|#{Regexp.escape("https://oaidalleapiprodscus.blob.core.windows.net/")}[^"]+|,
               "https://openai.com/generated/image.png"
  end
end
