# frozen_string_literal: true

require_relative "lib/llm/version"

Gem::Specification.new do |spec|
  spec.name = "llm.rb"
  spec.version = LLM::VERSION
  spec.authors = ["Antar Azri", "0x1eef"]
  spec.email = ["azantar@proton.me", "0x1eef@proton.me"]

  spec.summary = <<~SUMMARY
  llm.rb is a zero-dependency Ruby toolkit for Large Language Models that
  includes OpenAI, Gemini, Anthropic, xAI (grok), zAI, DeepSeek, Ollama, and
  LlamaCpp. The toolkit includes full support for chat, streaming, tool calling,
  audio, images, files, and structured outputs.
  SUMMARY

  spec.description = spec.summary
  spec.homepage = "https://github.com/llmrb/llm"
  spec.license = "0BSD"
  spec.required_ruby_version = ">= 3.2.0"

  spec.metadata["homepage_uri"] = spec.homepage
  spec.metadata["source_code_uri"] = "https://github.com/llmrb/llm"

  spec.files = Dir[
    "README.md", "LICENSE",
    "lib/*.rb", "lib/**/*.rb",
    "llm.gemspec"
  ]
  spec.require_paths = ["lib"]

  spec.add_development_dependency "webmock", "~> 3.24.0"
  spec.add_development_dependency "yard", "~> 0.9.37"
  spec.add_development_dependency "kramdown", "~> 2.4"
  spec.add_development_dependency "webrick", "~> 1.8"
  spec.add_development_dependency "test-cmd.rb", "~> 0.12.0"
  spec.add_development_dependency "rake", "~> 13.0"
  spec.add_development_dependency "rspec", "~> 3.0"
  spec.add_development_dependency "standard", "~> 1.50"
  spec.add_development_dependency "vcr", "~> 6.0"
  spec.add_development_dependency "dotenv", "~> 2.8"
  spec.add_development_dependency "net-http-persistent", "~> 4.0"
  spec.add_development_dependency "opentelemetry-sdk", "~> 1.10"
end
