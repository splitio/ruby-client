# frozen_string_literal: true

require 'spec_helper'

describe SplitIoClient::Engine::FallbackTreatmentCalculator do
  context 'works' do
    it 'process fallback treatments' do
        fallback_config = SplitIoClient::Engine::Models::FallbackTreatmentsConfiguration.new(SplitIoClient::Engine::Models::FallbackTreatment.new("on" ,"{}"))
        fallback_calculator = SplitIoClient::Engine::FallbackTreatmentCalculator.new(fallback_config)
        expect(fallback_calculator.fallback_treatments_configuration).to be fallback_config
        expect(fallback_calculator.label_prefix).to eq("fallback - ")
        
        fallback_treatment = fallback_calculator.resolve("feature", "not ready")
        expect(fallback_treatment.treatment).to eq("on")
        expect(fallback_treatment.label).to eq("fallback - not ready")
        expect(fallback_treatment.config).to eq("{}")
        
        fallback_calculator.fallback_treatments_configuration = SplitIoClient::Engine::Models::FallbackTreatmentsConfiguration.new(SplitIoClient::Engine::Models::FallbackTreatment.new("on" ,"{}"), {:feature => SplitIoClient::Engine::Models::FallbackTreatment.new("off" , '{"prop": "val"}')})
        fallback_treatment = fallback_calculator.resolve(:feature, "not ready")
        expect(fallback_treatment.treatment).to eq("off")
        expect(fallback_treatment.label).to eq("fallback - not ready")
        expect(fallback_treatment.config).to eq('{"prop": "val"}')
        
        fallback_treatment = fallback_calculator.resolve(:feature2, "not ready")
        expect(fallback_treatment.treatment).to eq("on")
        expect(fallback_treatment.label).to eq("fallback - not ready")
        expect(fallback_treatment.config).to eq("{}")
    end
  end
end
