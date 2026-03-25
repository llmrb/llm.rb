# frozen_string_literal: true

class LLM::Schema
  ##
  # The {LLM::Schema::Parser LLM::Schema::Parser} module provides
  # methods for parsing a JSON schema into {LLM::Schema::Leaf}
  # objects. It is used by {LLM::Schema LLM::Schema} to convert
  # external JSON schema definitions into the schema objects used
  # throughout llm.rb.
  module Parser
    ##
    # Parses a JSON schema into an {LLM::Schema::Leaf}.
    # @param [Hash] schema
    #  The JSON schema to parse
    # @raise [TypeError]
    #  When the schema is not supported
    # @return [LLM::Schema::Leaf]
    def parse(schema)
      schema = schema.to_h if schema.respond_to?(:to_h)
      raise TypeError, "expected Hash but got #{schema.class}" unless Hash === schema
      schema = schema.transform_keys(&:to_s)
      case schema["type"]
      when "object" then apply(parse_object(schema), schema)
      when "array" then apply(parse_array(schema), schema)
      when "string" then apply(parse_string(schema), schema)
      when "integer" then apply(parse_integer(schema), schema)
      when "number" then apply(parse_number(schema), schema)
      when "boolean" then apply(schema().boolean, schema)
      when "null" then apply(schema().null, schema)
      else raise TypeError, "unsupported schema type #{schema["type"].inspect}"
      end
    end

    private

    def parse_object(schema)
      properties = (schema["properties"] || {}).transform_keys(&:to_s).transform_values { parse(_1) }
      required = schema["required"] || []
      required.each do |key|
        next unless properties[key]
        properties[key].required
      end
      schema().object(properties)
    end

    def parse_array(schema)
      items = schema["items"] ? parse(schema["items"]) : schema().null
      schema().array(items)
    end

    def parse_string(schema)
      leaf = schema().string
      leaf.min(schema["minLength"]) if schema.key?("minLength")
      leaf.max(schema["maxLength"]) if schema.key?("maxLength")
      leaf
    end

    def parse_integer(schema)
      leaf = schema().integer
      leaf.min(schema["minimum"]) if schema.key?("minimum")
      leaf.max(schema["maximum"]) if schema.key?("maximum")
      leaf.multiple_of(schema["multipleOf"]) if schema.key?("multipleOf")
      leaf
    end

    def parse_number(schema)
      leaf = schema().number
      leaf.min(schema["minimum"]) if schema.key?("minimum")
      leaf.max(schema["maximum"]) if schema.key?("maximum")
      leaf.multiple_of(schema["multipleOf"]) if schema.key?("multipleOf")
      leaf
    end

    def apply(leaf, schema)
      leaf.description(schema["description"]) if schema.key?("description")
      leaf.default(schema["default"]) if schema.key?("default")
      leaf.enum(*schema["enum"]) if schema.key?("enum")
      leaf.const(schema["const"]) if schema.key?("const")
      leaf
    end
  end
end
