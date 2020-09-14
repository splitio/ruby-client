# frozen_string_literal: true

require 'spec_helper'

describe SplitIoClient::Engine::Common::ImpressionCounter do
  subject { SplitIoClient::Engine::Common::ImpressionCounter }

  before do
    @counter = subject.new
  end

  it 'truncate time frame' do
    expect(@counter.truncate_time_frame(make_timestamp('2020-09-02 10:53:12'))).to eq(make_timestamp('2020-09-02 10:00:00'))
    expect(@counter.truncate_time_frame(make_timestamp('2020-09-02 10:00:00'))).to eq(make_timestamp('2020-09-02 10:00:00'))
    expect(@counter.truncate_time_frame(make_timestamp('2020-09-02 10:53:00'))).to eq(make_timestamp('2020-09-02 10:00:00'))
    expect(@counter.truncate_time_frame(make_timestamp('2020-09-02 10:00:12'))).to eq(make_timestamp('2020-09-02 10:00:00'))
    expect(@counter.truncate_time_frame(make_timestamp('1970-01-01 00:00:00'))).to eq(make_timestamp('1970-01-01'))
  end

  it 'make key' do
    target = make_timestamp('2020-09-02 09:00:00')

    expect(@counter.make_key('feature_test', make_timestamp('2020-09-02 09:40:11'))).to eq("feature_test::#{target}")
    expect(@counter.make_key('feature_test', make_timestamp('2020-09-02 09:25:00'))).to eq("feature_test::#{target}")
    expect(@counter.make_key(nil, make_timestamp('2020-09-02 09:25:00'))).to eq("::#{target}")
    expect(@counter.make_key(nil, 0)).to eq('::0')
  end

  it 'basic usage' do
    @counter.inc('feature1', make_timestamp('2020-09-02 09:15:11'))
    @counter.inc('feature1', make_timestamp('2020-09-02 09:20:11'))
    @counter.inc('feature1', make_timestamp('2020-09-02 09:50:11'))
    @counter.inc('feature2', make_timestamp('2020-09-02 09:50:11'))
    @counter.inc('feature2', make_timestamp('2020-09-02 09:55:11'))
    @counter.inc('feature1', make_timestamp('2020-09-02 10:50:11'))

    result = @counter.pop_all

    expect(result["feature1::#{make_timestamp('2020-09-02 09:00:00')}"]).to eq(3)
    expect(result["feature2::#{make_timestamp('2020-09-02 09:00:00')}"]).to eq(2)
    expect(result["feature1::#{make_timestamp('2020-09-02 10:00:00')}"]).to eq(1)

    result = @counter.pop_all

    expect(result.size).to eq(0)
  end

  def make_timestamp(time)
    (Time.parse(time).to_f * 1000.0).to_i
  end
end
