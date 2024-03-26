require 'spec_helper'

describe SplitIoClient::Semver do
  let(:valid_versions) { ["1.1.2", "1.1.1", "1.0.0", "1.0.0-rc.1", "1.0.0-beta.11", "1.0.0-beta.2",
  "1.0.0-beta", "1.0.0-alpha.beta", "1.0.0-alpha.1", "1.0.0-alpha", "2.2.2-rc.2+metadata-lalala", "2.2.2-rc.1.2",
  "1.2.3", "0.0.4", "1.1.2+meta", "1.1.2-prerelease+meta", "1.0.0-beta", "1.0.0-alpha", "1.0.0-alpha0.valid",
  "1.0.0-alpha.0valid", "1.0.0-rc.1+build.1", "1.0.0-alpha-a.b-c-somethinglong+build.1-aef.1-its-okay",
  "10.2.3-DEV-SNAPSHOT", "1.2.3-SNAPSHOT-123", "1.1.1-rc2", "1.0.0-0A.is.legal", "1.2.3----RC-SNAPSHOT.12.9.1--.12+788",
  "1.2.3----R-S.12.9.1--.12+meta", "1.2.3----RC-SNAPSHOT.12.9.1--.12.88", "1.2.3----RC-SNAPSHOT.12.9.1--.12",
  "9223372036854775807.9223372036854775807.9223372036854775807", "9223372036854775807.9223372036854775807.9223372036854775806",
  "1.1.1-alpha.beta.rc.build.java.pr.support.10", "1.1.1-alpha.beta.rc.build.java.pr.support"] }

  context 'check versions' do
    it 'accept valid versions' do
      major = [1, 1, 1, 1, 1, 1,
        1, 1, 1, 1, 2, 2,
        1, 0, 1, 1, 1, 1, 1,
        1, 1, 1,
        10, 1, 1, 1, 1,
        1, 1, 1,
        9223372036854775807, 9223372036854775807,
        1,1]
      minor = [1, 1, 0, 0, 0, 0,
        0, 0, 0, 0, 2, 2,
        2, 0, 1, 1, 0, 0, 0,
        0, 0, 0,
        2, 2, 1, 0, 2,
        2, 2, 2,
        9223372036854775807, 9223372036854775807,
        1, 1]
      patch = [2, 1, 0, 0, 0, 0,
        0, 0, 0, 0, 2, 2,
        3, 4, 2, 2, 0, 0, 0,
        0, 0, 0,
        3, 3, 1, 0, 3,
        3, 3, 3,
        9223372036854775807, 9223372036854775806,
        1, 1]
      pre_release = [[], [], [], ["rc","1"], ["beta","11"],["beta","2"],
        ["beta"], ["alpha","beta"], ["alpha","1"], ["alpha"], ["rc","2"], ["rc","1","2"],
        [], [], [], ["prerelease"], ["beta"], ["alpha"], ["alpha0","valid"],
        ["alpha","0valid"], ["rc","1"], ["alpha-a","b-c-somethinglong"],
        ["DEV-SNAPSHOT"], ["SNAPSHOT-123"], ["rc2"], ["0A","is","legal"], ["---RC-SNAPSHOT","12","9","1--","12"],
        ["---R-S","12","9","1--","12"], ["---RC-SNAPSHOT","12","9","1--","12","88"], ["---RC-SNAPSHOT","12","9","1--","12"],
        [], [],
        ["alpha","beta","rc","build","java","pr","support","10"], ["alpha","beta","rc","build","java","pr","support"]]

      for i in (0..major.length-1)
        semver = described_class.new(valid_versions[i])
        expect(verify_version(semver, major[i], minor[i], patch[i], pre_release[i], pre_release[i]==[])).to eq(true)
      end
    end
    it 'reject invalid versions' do
      invalid_versions = [
        "1", "1.2", "1.alpha.2", "+invalid", "-invalid", "-invalid+invalid", "+justmeta",
        "-invalid.01", "alpha", "alpha.beta", "alpha.beta.1", "alpha.1", "alpha+beta",
        "alpha_beta", "alpha.", "alpha..", "beta", "-alpha.", "1.2", "1.2.3.DEV", "-1.0.3-gamma+b7718",
        "1.2-SNAPSHOT", "1.2.31.2.3----RC-SNAPSHOT.12.09.1--..12+788", "1.2-RC-SNAPSHOT"]

      for version in invalid_versions
        expect{ described_class.new(version) }.to raise_error(RuntimeError)
      end
    end
  end

  context 'compare versions' do
    it 'higher, lower and equal' do
      cnt = 0
      for i in (0..(valid_versions.length/2).to_i-1)
        expect(described_class.new(valid_versions[cnt]).compare(described_class.new(valid_versions[cnt+1]))).to eq(1)
        expect(described_class.new(valid_versions[cnt+1]).compare(described_class.new(valid_versions[cnt]))).to eq(-1)
        expect(described_class.new(valid_versions[cnt]).compare(described_class.new(valid_versions[cnt]))).to eq(0)
        expect(described_class.new(valid_versions[cnt+1]).compare(described_class.new(valid_versions[cnt+1]))).to eq(0)
        cnt = cnt + 2
      end
      expect(described_class.new("1.1.1").compare(described_class.new("1.1.1"))).to eq(0)
      expect(described_class.new("1.1.1").compare(described_class.new("1.1.1+metadata"))).to eq(0)
      expect(described_class.new("1.1.1").compare(described_class.new("1.1.1-rc.1"))).to eq(1)
      expect(described_class.new("88.88.88").compare(described_class.new("88.88.88"))).to eq(0)
      expect(described_class.new("1.2.3----RC-SNAPSHOT.12.9.1--.12").compare(described_class.new("1.2.3----RC-SNAPSHOT.12.9.1--.12"))).to eq(0)
      expect(described_class.new("10.2.3-DEV-SNAPSHOT").compare(described_class.new("10.2.3-SNAPSHOT-123"))).to eq(-1)
    end
  end

  def verify_version(semver, major, minor, patch, pre_release="", is_stable=True)
    if semver.major == major and semver.minor == minor and semver.patch == patch and
      semver.pre_release == pre_release and semver.is_stable == is_stable
      return true
    end
    return false
  end
end
