# frozen_string_literal: true

require 'spec_helper'

describe SplitIoClient::Engine::Models::FallbackTreatmentsConfiguration do
  context 'works' do
    it 'it converts string to fallback treatment' do
      fb_config = described_class.new("global", {:feature => "local"})
      expect(fb_config.global_fallback_treatment.is_a?(SplitIoClient::Engine::Models::FallbackTreatment)).to be true
      expect(fb_config.global_fallback_treatment.treatment).to be "global"

      expect(fb_config.by_flag_fallback_treatment[:feature].is_a?(SplitIoClient::Engine::Models::FallbackTreatment)).to be true
      expect(fb_config.by_flag_fallback_treatment[:feature].treatment).to be "local"
    end
  end
end
