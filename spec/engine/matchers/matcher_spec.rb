# frozen_string_literal: true

describe SplitIoClient::Matcher do
  context '#equals?' do
    let(:matcher) { described_class.new }
    it 'is equal' do
      expect(matcher.equals?(matcher)).to be true
    end
    it 'is not equal because the object is nil' do
      expect(described_class.new.equals?(nil)).to be false
    end
    it 'is not equal because other type' do
      expect(described_class.new.equals?('string')).to be false
    end
    it 'is not equal because is other instance' do
      expect(described_class.new.equals?(described_class.new)).to be false
    end
  end
end
