# frozen_string_literal: true

require 'spec_helper'

describe SplitIoClient::Api::SegmentsJSONLocalhost do
  context '#sync_segments' do
    it 'log error if invalid segment folder' do
      log = StringIO.new
      config = SplitIoClient::SplitConfig.new(
        logger: Logger.new(log),
        debug_enabled: true,
        segment_directory: '//invalid/,/,/',
        cache_adapter: :memory
      )
      segments_repository = SplitIoClient::Cache::Repositories::SegmentsRepository.new(config)
      segment_api = SplitIoClient::Api::SegmentsJSONLocalhost.new(segments_repository, config)
      segment_api.fetch_segments_by_names(['segment'])
      expect(log.string).to include "Error parsing file for segment 'segment'"
    end

    it 'add new segment' do
      log = StringIO.new
      config = SplitIoClient::SplitConfig.new(
        logger: Logger.new(log),
        debug_enabled: true,
        segment_directory: File.expand_path('../../../../test_data/segments', __FILE__),
        cache_adapter: :memory
      )
      segments_repository = SplitIoClient::Cache::Repositories::SegmentsRepository.new(config)
      segment_api = SplitIoClient::Api::SegmentsJSONLocalhost.new(segments_repository, config)
      segment_api.fetch_segments_by_names(['employees'])
      expect(segments_repository.get_segment_keys('employees')).to eq(["max", "dan"])
      expect(segments_repository.get_change_number('employees')).to eq(1473863075059)
    end

    it 'sync existing segment' do
      log = StringIO.new
      config = SplitIoClient::SplitConfig.new(
        logger: Logger.new(log),
        debug_enabled: true,
        segment_directory: File.expand_path('../../../../test_data/segments', __FILE__),
        cache_adapter: :memory
      )
      segments_repository = SplitIoClient::Cache::Repositories::SegmentsRepository.new(config)
      segment_api = SplitIoClient::Api::SegmentsJSONLocalhost.new(segments_repository, config)
      segment_api.fetch_segments_by_names(['employees'])
      expect(segments_repository.get_segment_keys('employees')).to eq(["max", "dan"])
      expect(segments_repository.get_change_number('employees')).to eq(1473863075059)

      # no update when segment file content has not changed
      segment_api.fetch_segments_by_names(['employees'])
      expect(log.string).not_to include("segment is updated")

      # no update if till timestamp is lower than stored one.
      update_segment('till', 1234)
      sleep 0.2
      segment_api.fetch_segments_by_names(['employees'])
      expect(log.string).not_to include("segment is updated")

      # update segment.
      update_segment('till', 1473863075059)
      sleep 0.2
      update_segment('removed', ["max"])
      sleep 0.2
      update_segment('added', ["joe"])
      sleep 0.2
      segment_api.fetch_segments_by_names(['employees'])
      expect(log.string).to include("segment is updated")
      expect(segments_repository.get_segment_keys('employees')).to eq(["dan", "joe"])

      # restore file
      update_segment('removed', [])
      sleep 0.2
      update_segment('added', ["max", "dan"])
      sleep 0.2
    end
  end

  context '#sanitize_segments' do
    config = SplitIoClient::SplitConfig.new(
      segment_directory: File.expand_path('../../../../test_data/segments', __FILE__),
      cache_adapter: :memory
    )
    segments_repository = SplitIoClient::Cache::Repositories::SegmentsRepository.new(config)
    segment_api = SplitIoClient::Api::SegmentsJSONLocalhost.new(segments_repository, config)

    it 'test sanitize name' do
      # should reject segment if 'name' is null
      segment = {:name => nil, :added => [], :removed => [], :since => -1, :till => 12}
      expect { segment_api.send(:sanitize_segment, segment) }.to raise_error(RuntimeError)

      # should reject segment if 'name' is empty
      segment = {:name => "", :added => [], :removed => [], :since => -1, :till => 12}
      expect { segment_api.send(:sanitize_segment, segment) }.to raise_error(RuntimeError)

      # should reject segment if 'name' does not exist
      segment = {:added => [], :removed => [], :since => -1, :till => 12}
      expect { segment_api.send(:sanitize_segment, segment) }.to raise_error(RuntimeError)
    end

    it 'test sanitize missing fields' do
      # should add missing 'added' element
      segment = {:name => 'segment1', :removed => [], :since => -1, :till => 12}
      expect(segment_api.send(:sanitize_segment, segment)).to eq({:name => 'segment1', :added => [], :removed => [], :since => -1, :till => 12})

      # should add missing 'removed' element
      segment = {:name => 'segment1', :added => [], :since => -1, :till => 12}
      expect(segment_api.send(:sanitize_segment, segment)).to eq({:name => 'segment1', :added => [], :removed => [], :since => -1, :till => 12})

      # should add since and till with -1 if they are missing
      segment = {:name => 'segment1', :added => [], :removed => []}
      expect(segment_api.send(:sanitize_segment, segment)).to eq({:name => 'segment1', :added => [], :removed => [], :since => -1, :till => -1})
    end

    it 'test reset incorrect values' do
      # should reset added and remved to array if values are None
      segment = {:name => 'segment1', :added => nil, :removed => nil, :since => -1, :till => 12}
      expect(segment_api.send(:sanitize_segment, segment)).to eq({:name => 'segment1', :added => [], :removed => [], :since => -1, :till => 12})

      # should reset since and till to -1 if values are None
      segment = {:name => 'segment1', :added => [], :removed => [], :since => -1, :till => nil}
      expect(segment_api.send(:sanitize_segment, segment)).to eq({:name => 'segment1', :added => [], :removed => [], :since => -1, :till => -1})

      # should reset since and till to -1 if values are 0
      segment = {:name => 'segment1', :added => [], :removed => [], :since => 0, :till => 0}
      expect(segment_api.send(:sanitize_segment, segment)).to eq({:name => 'segment1', :added => [], :removed => [], :since => -1, :till => -1})

      # should reset till and since to -1 if values below -1
      segment = {:name => 'segment1', :added => [], :removed => [], :since => -44, :till => -2}
      expect(segment_api.send(:sanitize_segment, segment)).to eq({:name => 'segment1', :added => [], :removed => [], :since => -1, :till => -1})

      # should reset since to till if value above till
      segment = {:name => 'segment1', :added => [], :removed => [], :since => 40, :till => 12}
      expect(segment_api.send(:sanitize_segment, segment)).to eq({:name => 'segment1', :added => [], :removed => [], :since => 12, :till => 12})
    end
  end
end

def update_segment(field, value)
  parsed = JSON.parse(File.read(File.join(File.expand_path('../../../../test_data/segments', __FILE__), 'employees')))
  parsed[field] = value
  File.write(File.join(File.expand_path('../../../../test_data/segments', __FILE__), 'employees'), JSON.dump(parsed))
end
