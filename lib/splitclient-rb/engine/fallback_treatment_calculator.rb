# frozen_string_literal: true

module SplitIoClient
  module Engine
    class FallbackTreatmentCalculator
      attr_accessor :fallback_treatments_configuration, :label_prefix

      def initialize(fallback_treatment_configuration)
        @label_prefix = 'fallback - '
        @fallback_treatments_configuration = fallback_treatment_configuration
      end

      def resolve(flag_name, label)
        default_fallback_treatment = Engine::Models::FallbackTreatment.new(
          Engine::Models::Treatment::CONTROL,
          nil,
          label
        )
        return default_fallback_treatment if @fallback_treatments_configuration.nil?

        if !@fallback_treatments_configuration.by_flag_fallback_treatment.nil? \
            && !@fallback_treatments_configuration.by_flag_fallback_treatment.fetch(flag_name, nil).nil?
          return copy_with_label(
            @fallback_treatments_configuration.by_flag_fallback_treatment[flag_name],
            resolve_label(label)
          )
        end

        return copy_with_label(@fallback_treatments_configuration.global_fallback_treatment, resolve_label(label)) \
          unless @fallback_treatments_configuration.global_fallback_treatment.nil?

        default_fallback_treatment
      end

      private

      def resolve_label(label)
        return nil if label.nil?

        @label_prefix + label
      end

      def copy_with_label(fallback_treatment, label)
        Engine::Models::FallbackTreatment.new(fallback_treatment.treatment, fallback_treatment.config, label)
      end
    end
  end
end
