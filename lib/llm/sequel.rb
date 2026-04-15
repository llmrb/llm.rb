# frozen_string_literal: true

module LLM::Sequel
  ##
  # Sequel plugin for persisting {LLM::Context LLM::Context} state.
  #
  # This plugin maps model columns onto provider selection, model
  # selection, usage accounting, and serialized context data while
  # leaving application-specific concerns such as credentials,
  # associations, and UI shaping to the host app.
  module Plugin
    EMPTY_HASH = {}.freeze
    DEFAULT_USAGE_COLUMNS = {
      input_tokens: :input_tokens,
      output_tokens: :output_tokens,
      total_tokens: :total_tokens
    }.freeze
    DEFAULTS = {
      provider_column: :provider,
      model_column: :model,
      data_column: :data,
      usage_columns: DEFAULT_USAGE_COLUMNS,
      provider_params: EMPTY_HASH,
      context_params: EMPTY_HASH
    }.freeze

    def self.apply(model, **)
      model.extend ClassMethods
      model.include InstanceMethods
    end

    def self.configure(model, options = EMPTY_HASH)
      options = DEFAULTS.merge(options)
      usage_columns = DEFAULT_USAGE_COLUMNS.merge(options[:usage_columns] || EMPTY_HASH)
      model.instance_variable_set(
        :@llm_plugin_options,
        options.merge(usage_columns: usage_columns.freeze).freeze
      )
    end

    module ClassMethods
      ##
      # @return [Hash]
      def llm_plugin_options
        @llm_plugin_options || DEFAULTS
      end
    end

    module InstanceMethods
      ##
      # Continues the stored context with new input and flushes it.
      # @return [LLM::Response]
      def talk(...)
        ctx.talk(...).tap { flush }
      end

      ##
      # Continues the stored context through the Responses API and flushes it.
      # @return [LLM::Response]
      def respond(...)
        ctx.respond(...).tap { flush }
      end

      ##
      # Waits for queued tool work to finish and flushes the context.
      # @return [Array<LLM::Function::Return>]
      def wait(...)
        ctx.wait(...).tap { flush }
      end

      ##
      # @return [Array<LLM::Message>]
      def messages
        ctx.messages
      end

      ##
      # @return [String]
      def model_name
        ctx.model
      end

      ##
      # @return [Array<LLM::Function>]
      def functions
        ctx.functions
      end

      ##
      # @return [LLM::Cost]
      def cost
        ctx.cost
      end

      ##
      # @return [Integer]
      def context_window
        ctx.context_window
      rescue LLM::NoSuchModelError, LLM::NoSuchRegistryError
        0
      end

      ##
      # Returns the resolved provider instance for this record.
      # @return [LLM::Provider]
      def llm
        options = self.class.llm_plugin_options
        provider = self[options[:provider_column]]
        kwargs = resolve_options(options[:provider_params])
        @llm ||= LLM.method(provider).call(**kwargs)
      end

      ##
      # Returns usage from the mapped usage columns.
      # @return [LLM::Object]
      def usage
        columns = self.class.llm_plugin_options[:usage_columns]
        LLM::Object.from(
          input_tokens: public_send(columns[:input_tokens]) || 0,
          output_tokens: public_send(columns[:output_tokens]) || 0,
          total_tokens: public_send(columns[:total_tokens]) || 0
        )
      end

      private

      def ctx
        @ctx ||= begin
          options = self.class.llm_plugin_options
          params = resolve_options(options[:context_params]).dup
          params[:model] ||= self[options[:model_column]]
          context = LLM::Context.new(llm, params.compact)
          data = self[options[:data_column]]
          data.to_s.empty? ? context : context.restore(string: data)
        end
      end

      def flush
        options = self.class.llm_plugin_options
        columns = options[:usage_columns]
        update({
          options[:data_column] => ctx.to_json,
          columns[:input_tokens] => ctx.usage.input_tokens,
          columns[:output_tokens] => ctx.usage.output_tokens,
          columns[:total_tokens] => ctx.usage.total_tokens
        })
      end

      def resolve_option(option)
        case option
        when Proc then instance_exec(&option)
        when Hash then option.dup
        else option
        end
      end

      def resolve_options(option)
        case option
        when Proc, Hash then resolve_option(option)
        else EMPTY_HASH.dup
        end
      end
    end
  end
end
