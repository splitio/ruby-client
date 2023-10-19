# frozen_string_literal: true
require 'spec_helper'

describe SplitIoClient::Cache::Filter::FlagSetsFilter do
  subject { SplitIoClient::Cache::Filter::FlagSetsFilter }

  it 'validate initialize, contains one or multiple sets' do
    fs = subject.new(['set_1', 'set_2'])

    expect(fs.flag_set_exist?('set_1')).to eq(true)
    expect(fs.flag_set_exist?('set_3')).to eq(false)
    expect(fs.intersect?(['set_3', 'set_1'])).to eq(true)
    expect(fs.intersect?(['set_2', 'set_1'])).to eq(true)
    expect(fs.intersect?(['set_3', 'set_4'])).to eq(false)

  end
end
