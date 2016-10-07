require 'spec_helper'

describe SplitIoClient::CombiningMatcher do
  subject { SplitIoClient::SplitFactory.new('', { logger: Logger.new('/dev/null') }).client }

  let(:splits_json) { File.read(File.expand_path(File.join(File.dirname(__FILE__), '../../test_data/splits/combining_matcher_splits.json'))) }
  let(:segments_json) { File.read(File.expand_path(File.join(File.dirname(__FILE__), '../../test_data/segments/combining_matcher_segments.json'))) }

  before do
    stub_request(:get, 'https://sdk.split.io/api/segmentChanges/employees?since=-1')
      .to_return(status: 200, body: segments_json)
    stub_request(:get, 'https://sdk.split.io/api/splitChanges?since=-1')
      .to_return(status: 200, body: splits_json)
  end
end
