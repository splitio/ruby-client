module SplitIoClient::Engine::Models
    class FallbackTreatmentsConfiguration
    attr_accessor :global_fallback_treatment, :by_flag_fallback_treatment

    def initialize(global_fallback_treatment=nil, by_flag_fallback_treatment=nil)
        @global_fallback_treatment = build_global_fallback_treatment(global_fallback_treatment)
        @by_flag_fallback_treatment = build_by_flag_fallback_treatment(by_flag_fallback_treatment)
    end

    private 

    def build_global_fallback_treatment(global_fallback_treatment)
      if global_fallback_treatment.is_a? String
        return FallbackTreatment.new(global_fallback_treatment)
      end
      
      global_fallback_treatment
    end

    def build_by_flag_fallback_treatment(by_flag_fallback_treatment)
      return nil unless by_flag_fallback_treatment.is_a?(Hash)
      processed_by_flag_fallback_treatment = Hash.new
      
      by_flag_fallback_treatment.each do |key, value|
        if value.is_a? String
          processed_by_flag_fallback_treatment[key] = FallbackTreatment.new(value)
          next
        end

        processed_by_flag_fallback_treatment[key] = value
      end

      processed_by_flag_fallback_treatment
    end
  end
end
