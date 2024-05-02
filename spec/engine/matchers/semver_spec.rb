require 'spec_helper'
require 'csv'

describe SplitIoClient::Semver do
  let(:valid_versions) do
    CSV.parse(File.read(File.expand_path(File.join(File.dirname(__FILE__),
                                         '../../test_data/splits/semver/valid-semantic-versions.csv'))), headers: true)
  end
  let(:invalid_versions) do
    CSV.parse(File.read(File.expand_path(File.join(File.dirname(__FILE__),
                                         '../../test_data/splits/semver/invalid-semantic-versions.csv'))), headers: true)
  end
  let(:equal_to_versions) do
    CSV.parse(File.read(File.expand_path(File.join(File.dirname(__FILE__),
                                         '../../test_data/splits/semver/equal-to-semver.csv'))), headers: true)
  end

  let(:between_versions) do
    CSV.parse(File.read(File.expand_path(File.join(File.dirname(__FILE__),
                                         '../../test_data/splits/semver/between-semver.csv'))), headers: true)
  end

  let(:logger) { Logger.new('/dev/null') }

  context 'check versions' do
    it 'accept valid versions' do
      for i in (0..valid_versions.length-1)
        expect(described_class.build(valid_versions[i][0], logger)).not_to be_nil
      end
    end
    it 'reject invalid versions' do
      for version in invalid_versions
        expect(described_class.build(version[0], logger)).to eq(nil)
      end
    end

    it 'verify leading-zero integers are converted' do
      semver = described_class.build('1.01.2', logger)
      expect(semver.version).to eq('1.1.2')
      expect(described_class.build('1.01.2-rc.04', logger).version).to eq('1.1.2-rc.4')
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
        if equal_to_versions[i][2]=='true'
          expect(described_class.build(equal_to_versions[i][0], logger).version == described_class.build(equal_to_versions[i][1], logger).version).to eq(true)
        else
          expect(described_class.build(equal_to_versions[i][0], logger) == described_class.build(equal_to_versions[i][1], logger)).to eq(false)
        end
      end
      for i in (1..between_versions.length-1)
        sem1 = described_class.build(between_versions[i][0], logger)
        sem2 = described_class.build(between_versions[i][2], logger)
        to_check = described_class.build(between_versions[i][1], logger)
        if between_versions[i][3]=='true'
          expect(sem1.compare(to_check)).to eq(-1)
          expect(sem2.compare(to_check)).to eq(1)
        else
          compare1 = sem1.compare(to_check)
          compare2 = sem2.compare(to_check)
          expect(compare1 == -1 && compare2 == 1).to eq(false)
        end
      end

    end
  end
end
