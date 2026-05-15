# frozen_string_literal: true

class LLM::Tool
  ##
  # The {LLM::Tool::Param LLM::Tool::Param} module extends the
  # {LLM::Tool LLM::Tool} class with a "param" method that can
  # define a parameter for simple types. For complex types, use
  # {LLM::Tool.params LLM::Tool.params} instead.
  #
  # @example
  #   class Greeter < LLM::Tool
  #     name "greeter"
  #     description "Greets the user"
  #     parameter :name, String, "The user's name"
  #     required %i[name]
  #
  #     def call(name:)
  #       puts "Hello, #{name}!"
  #     end
  #   end
  module Param
    ##
    # @param name [Symbol]
    #   The name of a parameter
    # @param type [LLM::Schema::Leaf, Class]
    #   The parameter type (eg String)
    # @param description [String]
    #   The description of a property
    # @param options [Hash]
    #   A hash of options for the parameter
    # @option options [Boolean] :required
    #   Whether or not the parameter is required
    # @option options [Object] :default
    #   The default value for a given property
    # @option options [Array<String>] :enum
    #   One or more possible values for a param
    def param(name, type, description, options = {})
      lock do
        function.params do |schema|
          resolved = Utils.resolve(schema, type)
          schema.object(name => Utils.setup(resolved, description, options))
        end
      end
    end
    alias_method :parameter, :param

    ##
    # Mark existing parameters as required.
    # @param names [Array<Symbol,String>]
    # @return [LLM::Schema::Object]
    def required(names)
      lock do
        function.params.tap do |schema|
          [*names].each { Utils.fetch(schema.properties, _1).required }
        end
      end
    end

    ##
    # @api private
    module Utils
      extend self

      def resolve(schema, type)
        LLM::Schema::Utils.resolve(schema, type)
      end

      def setup(leaf, description, options)
        required = options.fetch(:required, false)
        default = options.fetch(:default, nil)
        enum = options.fetch(:enum, nil)
        leaf.required if required
        leaf.description(description) if description
        leaf.default(default) if default
        leaf.enum(*enum) if enum
        leaf
      end

      def fetch(properties, name)
        properties[name] || properties.fetch(name.to_s)
      end
    end
  end
end
