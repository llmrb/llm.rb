# frozen_string_literal: true

##
# The {LLM::Tracer LLM::Tracer} provides a tracer for debugging,
# logging, or feeding into an eval framework.
module LLM::Tracer
  require_relative "tracer/span"
  require_relative "tracer/event"
  require_relative "tracer/tracer"
  require_relative "tracer/null"
end
