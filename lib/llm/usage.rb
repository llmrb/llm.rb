# frozen_string_literal: true

##
# The {LLM::Usage LLM::Usage} class represents token usage for
# a given conversation or completion. As a conversation grows,
# so does the number of tokens used. This class helps track
# the number of input, output, reasoning, cache, and overall
# token count. It can also help track usage of the context
# window (which may vary by model).
class LLM::Usage < Struct.new(
  :input_tokens, :output_tokens, :reasoning_tokens,
  :input_audio_tokens, :output_audio_tokens, :input_image_tokens,
  :cache_read_tokens, :cache_write_tokens, :total_tokens, keyword_init: true
)
  ##
  # @return [String]
  def to_json(...)
    LLM.json.dump({
      input_tokens:, output_tokens:,
      reasoning_tokens:,
      input_audio_tokens:, output_audio_tokens:, input_image_tokens:,
      cache_read_tokens:, cache_write_tokens:, total_tokens:
    })
  end
end
