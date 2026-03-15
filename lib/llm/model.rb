# frozen_string_literal: true

##
# The {LLM::Model LLM::Model} class provides a normalized view of
# a provider model record returned by the models API.
class LLM::Model
  ##
  # The provider-specific model payload.
  # @return [LLM::Object]
  attr_reader :raw

  ##
  # @param [LLM::Object, Hash] raw
  def initialize(raw)
    @raw = raw
  end

  ##
  # Returns a normalized identifier suitable for API calls.
  # @return [String, nil]
  def id
    normalize_id(raw.id || raw.model || raw.name)
  end

  ##
  # Returns a display-friendly model name.
  # @return [String, nil]
  def name
    raw.display_name || raw.displayName || id
  end

  ##
  # Best-effort predicate for chat support.
  # @return [Boolean]
  def chat?
    return true if anthropic?
    return [*(raw.supportedGenerationMethods || [])].include?("generateContent") if gemini?
    openai_compatible_chat?
  end

  ##
  # Returns a Hash representation of the normalized model.
  # @return [Hash]
  def to_h
    {id:, name:, chat?: chat?}.compact
  end

  ##
  # @private
  module Collection
    include ::Enumerable

    ##
    # @yield [model]
    # @yieldparam [LLM::Model] model
    # @return [Enumerator, void]
    def each(&)
      return enum_for(:each) unless block_given?
      models.each(&)
    end

    ##
    # Returns an element, or a slice, or nil.
    # @return [Object, Array<Object>, nil]
    def [](*pos, **kw)
      models[*pos, **kw]
    end

    ##
    # @return [Boolean]
    def empty?
      models.empty?
    end

    ##
    # @return [Integer]
    def size
      models.size
    end

    ##
    # Returns normalized models.
    # @return [Array<LLM::Model>]
    def models
      @models ||= raw_models.map { LLM::Model.new(_1) }
    end
  end

  private

  def normalize_id(value)
    value&.sub(%r{\Amodels/}, "")
  end

  def anthropic?
    raw.type == "model" && raw.key?(:display_name) && raw.key?(:created_at)
  end

  def gemini?
    raw.key?(:supportedGenerationMethods)
  end

  def openai_compatible_chat?
    value = [id, raw.name, raw.model].compact.join(" ").downcase
    return false if value.include?("embedding")
    return false if value.include?("moderation")
    return false if value.include?("tts")
    return false if value.include?("transcrib")
    return false if value.include?("image")
    return false if value.include?("whisper")
    return false if value.include?("dall")
    return false if value.include?("omni-moderation")
    true
  end
end
