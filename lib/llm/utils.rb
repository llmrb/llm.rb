# frozen_string_literal: true

module LLM
  ##
  # Shared utility methods used across the runtime.
  module Utils
    extend self

    ##
    # Resolves a configured option against an object instance.
    #
    # Proc values are evaluated with `instance_exec`, symbol values are
    # sent to the object as method calls, hashes are duplicated, and all
    # other values are returned as-is.
    #
    # @param [Object] obj
    # @param [Object] option
    # @return [Object]
    def resolve_option(obj, option)
      case option
      when Proc then obj.instance_exec(&option)
      when Symbol then obj.send(option)
      when Hash then option.dup
      else option
      end
    end
  end
end
