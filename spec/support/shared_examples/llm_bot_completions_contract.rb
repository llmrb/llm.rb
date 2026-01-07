# frozen_string_literal: true

RSpec.shared_examples "LLM::Bot: completions contract" do |provider, options = {}|
  vcr = lambda do |basename|
    {vcr: {cassette_name: "#{provider}/chat/#{basename}"}.merge(options)}
  end

  context "when given a completion contract for #{provider}", vcr.call("completion_contract") do
    let(:llm) { LLM.method(provider).call(key:) }
    let(:bot) { LLM::Bot.new(llm) }

    subject(:completion) { bot.chat("Hello, world!") }

    it "implements the completion interface" do
      LLM::Completion.instance_methods(false).each do |m|
        expect(completion).to respond_to(m)
      end
    end

    it "returns choices as LLM::Message" do
      expect(completion.choices).to all(be_a(LLM::Message))
    end
  end
end
