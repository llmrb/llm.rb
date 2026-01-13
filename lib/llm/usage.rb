# frozen_string_literal: true

##
# The {LLM::Usage LLM::Usage} class represents token usage for
# a given conversation or completion. As a conversation grows,
# so does the number of tokens used. This class helps track
# the number of input, output, and total tokens. It can also help
# track usage of the context window (which may vary by model).
class LLM::Usage < Struct.new(:input_tokens, :output_tokens, :total_tokens, keyword_init: true)
end
