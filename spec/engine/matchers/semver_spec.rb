require 'spec_helper'
require 'csv'

describe SplitIoClient::Semver do
  let(:valid_versions) do
    CSV.parse(File.read(File.expand_path(File.join(File.dirname(__FILE__),
                                         '../../test_data/splits/semver/valid-semantic-versions.csv'))))
  end
  let(:invalid_versions) do
    CSV.parse(File.read(File.expand_path(File.join(File.dirname(__FILE__),
                                         '../../test_data/splits/semver/invalid-semantic-versions.csv'))))
  end
  let(:equal_to_versions) do
    CSV.parse(File.read(File.expand_path(File.join(File.dirname(__FILE__),
                                         '../../test_data/splits/semver/equal-to-semver.csv'))))
  end

  let(:logger) { Logger.new('/dev/null') }

  context 'check versions' do
    it 'accept valid versions' do
      for i in (0..valid_versions.length-1)
        expect(described_class.build(valid_versions[i][0], logger)).should_not be_nil
      end
    end
    it 'reject invalid versions' do
      for version in invalid_versions
        expect(described_class.build(version[0], logger)).to eq(nil)
      end
    end
  end

  context 'compare versions' do
    it 'equal and not equal' do
      for i in (1..valid_versions.length-1)
        expect(described_class.build(valid_versions[i][0], logger).compare(described_class.build(valid_versions[i][1], logger))).to eq(1)
        expect(described_class.build(valid_versions[i][1], logger).compare(described_class.build(valid_versions[i][0], logger))).to eq(-1)
        expect(described_class.build(valid_versions[i][0], logger).compare(described_class.build(valid_versions[i][0], logger))).to eq(0)
        expect(described_class.build(valid_versions[i][1], logger).compare(described_class.build(valid_versions[i][1], logger))).to eq(0)
      end
      for i in (1..equal_to_versions.length-1)
        if valid_versions[i][2]
          expect(described_class.build(valid_versions[i][0], logger).compare(described_class.build(valid_versions[i][1], logger))).to eq(0)
        else
          expect(described_class.build(valid_versions[i][0], logger).compare(described_class.build(valid_versions[i][1], logger))).not_to eq(0)
        end
      end
    end
  end
end
