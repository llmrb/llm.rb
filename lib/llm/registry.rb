# frozen_string_literal: true

##
# The {LLM::Registry LLM::Registry} class provides a small API over
# provider model data. It exposes model metadata such as pricing,
# capabilities, modalities, and limits from the registry files
# stored under `data/`. The data is provided by https://models.dev
# and shipped with llm.rb.
class LLM::Registry
  @root = File.join(__dir__, "..", "..")

  ##
  # @raise [LLM::Error]
  #  Might raise an error
  # @param [Symbol]
  #  A provider name
  # @return [LLM::Registry]
  def self.for(name)
    path = File.join @root, "data", "#{name}.json"
    if File.file?(path)
      new LLM.json.load(File.binread(path))
    else
      raise LLM::Error, "no registry found for #{name}"
    end
  end

  ##
  # @param [Hash] blob
  #  A model registry
  # @return [LLM::Registry]
  def initialize(blob)
    @registry = LLM::Object.from(blob)
    @models = @registry.models
  end

  ##
  # @return [LLM::Object]
  #  Returns model costs
  def cost(model:)
    if @models.key?(model)
      @models[model].cost
    else
      fallback = model.sub(/-\d{4}-\d{2}-\d{2}$/, "")
      if @models.key?(fallback)
        @models[fallback].cost
      else
        raise LLM::Error, "unknown model: #{model} (fallback: #{fallback})"
      end
    end
  end
end
