# frozen_string_literal: true

RSpec.shared_examples 'matchers equals spec' do |matcher|
  context '#equals?' do
    it 'is equal' do
      expect(matcher.equals?(matcher)).to be true
    end
    it 'is not equal because the object is nil' do
      expect(matcher.equals?(nil)).to be false
    end
    it 'is not equal because other type' do
      expect(matcher.equals?('string')).to be false
    end
  end
end
