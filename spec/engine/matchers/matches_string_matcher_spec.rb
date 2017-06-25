require 'spec_helper'

describe SplitIoClient::MatchesStringMatcher do
  let(:regexp_file) { File.read(File.expand_path(File.join(File.dirname(__FILE__), '../../test_data/regexp/data.txt'))) }

  it 'matches' do
    expect(described_class.new('value', %r{fo.}).match?(nil, value: 'foo')).to eq(true)
    expect(described_class.new('value', 'foo').match?(nil, value: 'foo')).to eq(true)
  end

  it 'does not match' do
    expect(described_class.new('value', %r{fo.}).match?(nil, value: 'bar')).to eq(false)
    expect(described_class.new('value', 'foo').match?(nil, value: 'bar')).to eq(false)
  end

  it 'matches sample regexps from file' do
    regexp_file.split("\n").each do |str|
      regexp_str, test_str, result_str = str.split('#')

      expect(
        described_class.new('key', Regexp.new(regexp_str)).match?(nil, key: test_str)
      ).to eq(result_str == 'true')
    end
  end
end
