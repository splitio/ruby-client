# frozen_string_literal: true

require 'spec_helper'

describe SplitIoClient::Api::SplitsJSONLocalhost do
  context '#sync_splits' do
    it 'log error if invalid segment folder' do
      log = StringIO.new
      config = SplitIoClient::SplitConfig.new(
        logger: Logger.new(log),
        debug_enabled: true,
        split_file: '//invalid/,/,/',
        cache_adapter: :memory
      )
      flag_sets_repository = SplitIoClient::Cache::Repositories::RedisFlagSetsRepository.new(config)
      flag_set_filter = SplitIoClient::Cache::Filter::FlagSetsFilter.new([])
      splits_repository = SplitIoClient::Cache::Repositories::SplitsRepository.new(config, flag_sets_repository, flag_set_filter)
      split_api = SplitIoClient::Api::SplitsJSONLocalhost.new(splits_repository, config)
      split_api.since
      expect(log.string).to include "Error parsing splits file"
    end

    it 'add new split' do
      config = SplitIoClient::SplitConfig.new(
        debug_enabled: true,
        split_file: File.expand_path('../../../../test_data/splits/splits_localhost.json', __FILE__),
        cache_adapter: :memory
      )
      flag_sets_repository = SplitIoClient::Cache::Repositories::RedisFlagSetsRepository.new(config)
      flag_set_filter = SplitIoClient::Cache::Filter::FlagSetsFilter.new([])
      splits_repository = SplitIoClient::Cache::Repositories::SplitsRepository.new(config, flag_sets_repository, flag_set_filter)
      split_api = SplitIoClient::Api::SplitsJSONLocalhost.new(splits_repository, config)
      splits_repository.set_change_number(-1)
      splits = split_api.since
      expect(splits[:splits].length).to eq(2)
      expect(splits[:splits][0][:name]).to eq('test_1_ruby')
      expect(splits[:till]).to eq(1473413807667)
    end

    it 'sync existing split' do
      log = StringIO.new
      config = SplitIoClient::SplitConfig.new(
        logger: Logger.new(log),
        debug_enabled: true,
        split_file: File.expand_path('../../../../test_data/splits/splits_localhost.json', __FILE__),
        cache_adapter: :memory
      )
      flag_sets_repository = SplitIoClient::Cache::Repositories::RedisFlagSetsRepository.new(config)
      flag_set_filter = SplitIoClient::Cache::Filter::FlagSetsFilter.new([])
      splits_repository = SplitIoClient::Cache::Repositories::SplitsRepository.new(config, flag_sets_repository, flag_set_filter)
      split_api = SplitIoClient::Api::SplitsJSONLocalhost.new(splits_repository, config)
      splits_repository.set_change_number(-1)
      splits = split_api.since
      expect(log.string).to include("2 feature flags retrieved")
      expect(splits[:splits][0][:defaultTreatment]).to eq("default")

      # no update when split file content has not changed
      splits = split_api.since
      expect(splits).to eq({})

      # no update if till timestamp is lower than stored one.
      splits_repository.set_change_number(1234)
      splits = split_api.since
      expect(splits).to eq({})

      # update split.
      update_splits(-1, 'till', 2473863075059)
      update_splits(0, 'defaultTreatment', 'on')
      splits = split_api.since
      expect(splits[:splits][0][:defaultTreatment]).to eq("on")

      # restore file
      update_splits(-1, 'till', 1473413807667)
      update_splits(0, 'defaultTreatment', 'default')
    end
  end

  context '#sanitize_splits' do
    config = SplitIoClient::SplitConfig.new(
      split_file: File.expand_path('../../../../test_data/splits/splits_localhost.json', __FILE__),
      cache_adapter: :memory
    )
    flag_sets_repository = SplitIoClient::Cache::Repositories::RedisFlagSetsRepository.new(config)
    flag_set_filter = SplitIoClient::Cache::Filter::FlagSetsFilter.new([])
    splits_repository = SplitIoClient::Cache::Repositories::SplitsRepository.new(config, flag_sets_repository, flag_set_filter)
    split_api = SplitIoClient::Api::SplitsJSONLocalhost.new(splits_repository, config)

    it 'test json elements' do
      # check no changes if all elements exist with valid values
      parsed = {"splits": [], "since": -1, "till": -1}
      expect(split_api.send(:sanitize_json_elements, parsed)).to eq(parsed)

      # check set since to -1 when is nil
      parsed2 = {"splits": [], "since": nil, "till": -1}
      expect(split_api.send(:sanitize_json_elements, parsed2)).to eq(parsed)

      # check no changes if since > -1
      parsed2 = {"splits": [], "since": 12, "till": -1}
      expect(split_api.send(:sanitize_json_elements, parsed2)).to eq(parsed)

      # check set till to -1 when is None
      parsed2 = {"splits": [], "since": 12, "till": nil}
      expect(split_api.send(:sanitize_json_elements, parsed2)).to eq(parsed)

      # check add since when missing
      parsed2 = {"splits": [], "till": -1}
      expect(split_api.send(:sanitize_json_elements, parsed2)).to eq(parsed)

      # check add till when missing
      parsed2 = {"splits": [], "since": -1}
      expect(split_api.send(:sanitize_json_elements, parsed2)).to eq(parsed)

      # check add splits when missing
      parsed2 = {"since": -1, "till": -1}
      expect(split_api.send(:sanitize_json_elements, parsed2)).to eq(parsed)
    end

    it 'test_split_incorrect_elements_sanitization' do
      splits_json = JSON.parse(File.read(File.expand_path('../../../../test_data/splits/splits_localhost.json', __FILE__)), symbolize_names: true)
      # No changes when split structure is good
      expect(split_api.send(:sanitize_feature_flag_elements, [splits_json[:splits][1]])).to eq([splits_json[:splits][1]])

      # test 'trafficTypeName' value None
      split = splits_json[:splits][1]
      split[:trafficTypeName] = nil
      expect(split_api.send(:sanitize_feature_flag_elements, [split])).to eq([splits_json[:splits][1]])

      # test 'trafficAllocation' value None
      split = splits_json[:splits][1]
      split[:trafficAllocation] = nil
      expect(split_api.send(:sanitize_feature_flag_elements, [split])).to eq([splits_json[:splits][1]])

      # test 'trafficAllocation' valid value should not change
      split = splits_json[:splits][1]
      split[:trafficAllocation] = 50
      expect(split_api.send(:sanitize_feature_flag_elements, [split])).to eq([split])

      # test 'trafficAllocation' invalid value should change
      split = splits_json[:splits][1]
      split[:trafficAllocation] = 110
      expect(split_api.send(:sanitize_feature_flag_elements, [split])).to eq([splits_json[:splits][1]])

      # test 'trafficAllocationSeed' is set to millisec epoch when None
      split = splits_json[:splits][1]
      split[:trafficAllocationSeed] = nil
      expect(split_api.send(:sanitize_feature_flag_elements, [split])[0][:trafficAllocationSeed]).to be > 0

      # test 'trafficAllocationSeed' is set to millisec epoch when 0
      split = splits_json[:splits][1]
      split[:trafficAllocationSeed] = 0
      expect(split_api.send(:sanitize_feature_flag_elements, [split])[0][:trafficAllocationSeed]).to be > 0

      # test 'seed' is set to millisec epoch when None
      split = splits_json[:splits][1]
      split[:seed] = nil
      expect(split_api.send(:sanitize_feature_flag_elements, [split])[0][:seed]).to be > 0

      # test 'seed' is set to millisec epoch when its 0
      split = splits_json[:splits][1]
      split[:seed] = 0
      expect(split_api.send(:sanitize_feature_flag_elements, [split])[0][:seed]).to be > 0

      # test 'status' is set to ACTIVE when None
      split = splits_json[:splits][1]
      split[:status] = nil
      expect(split_api.send(:sanitize_feature_flag_elements, [split])).to eq([splits_json[:splits][1]])

      # test 'status' is set to ACTIVE when incorrect
      split = splits_json[:splits][1]
      split[:status] = "w"
      expect(split_api.send(:sanitize_feature_flag_elements, [split])).to eq([splits_json[:splits][1]])

      # test ''killed' is set to False when incorrect
      split = splits_json[:splits][1]
      split[:killed] = nil
      expect(split_api.send(:sanitize_feature_flag_elements, [split])).to eq([splits_json[:splits][1]])

      # test 'defaultTreatment' is set to control when None
      split = splits_json[:splits][1]
      split[:defaultTreatment] = nil
      expect(split_api.send(:sanitize_feature_flag_elements, [split])[0][:defaultTreatment]).to eq('control')

      # test 'defaultTreatment' is set to control when its empty
      split = splits_json[:splits][1]
      split[:defaultTreatment] = ' '
      expect(split_api.send(:sanitize_feature_flag_elements, [split])[0][:defaultTreatment]).to eq('control')

      # test 'changeNumber' is set to 0 when None
      split = splits_json[:splits][1]
      split[:changeNumber] = nil
      expect(split_api.send(:sanitize_feature_flag_elements, [split])[0][:changeNumber]).to eq(0)

      # test 'changeNumber' is set to 0 when invalid
      split = splits_json[:splits][1]
      split[:changeNumber] = -33
      expect(split_api.send(:sanitize_feature_flag_elements, [split])[0][:changeNumber]).to eq(0)

      # test 'algo' is set to 2 when None
      split = splits_json[:splits][1]
      split[:algo] = nil
      expect(split_api.send(:sanitize_feature_flag_elements, [split])[0][:algo]).to eq(2)

      # test 'algo' is set to 2 when higher than 2
      split = splits_json[:splits][1]
      split[:algo] = 3
      expect(split_api.send(:sanitize_feature_flag_elements, [split])[0][:algo]).to eq(2)

      # test 'algo' is set to 2 when lower than 2
      split = splits_json[:splits][1]
      split[:algo] = 1
      expect(split_api.send(:sanitize_feature_flag_elements, [split])[0][:algo]).to eq(2)
    end

    it 'test_split_missing_elements_sanitization' do
      splits_json = JSON.parse(File.read(File.expand_path('../../../../test_data/splits/splits_localhost.json', __FILE__)), symbolize_names: true)

      # test missing all conditions with default rule set to 100% off
      split = splits_json[:splits][1]
      split.delete(:conditions)
      expect(split_api.send(:sanitize_feature_flag_elements, [split])[0][:conditions]).to eq([{
        :conditionType => "ROLLOUT",
        :matcherGroup => {
          :combiner => "AND",
          :matchers => [{
            :keySelector => { :trafficType => "user", :attribute => nil },
            :matcherType => "ALL_KEYS",
            :negate => false,
            :userDefinedSegmentMatcherData => nil,
            :whitelistMatcherData => nil,
            :unaryNumericMatcherData => nil,
            :betweenMatcherData => nil,
            :booleanMatcherData => nil,
            :dependencyMatcherData => nil,
            :stringMatcherData => nil
          }]
        }, :partitions => [
            { :treatment => "on", :size => 0 },
            { :treatment => "off", :size => 100 }
        ], :label => "default rule"
      }])

      # test missing ALL_KEYS condition matcher with default rule set to 100% off
      split = splits_json[:splits][0]
      expect(split_api.send(:sanitize_feature_flag_elements, [split])[0][:conditions][3]).to eq({
        :conditionType => "ROLLOUT",
        :matcherGroup => {
          :combiner => "AND",
          :matchers => [{
            :keySelector => { :trafficType => "user", :attribute => nil },
            :matcherType => "ALL_KEYS",
            :negate => false,
            :userDefinedSegmentMatcherData => nil,
            :whitelistMatcherData => nil,
            :unaryNumericMatcherData => nil,
            :betweenMatcherData => nil,
            :booleanMatcherData => nil,
            :dependencyMatcherData => nil,
            :stringMatcherData => nil
          }]
        }, :partitions => [
            { :treatment => "on", :size => 0 },
            { :treatment => "off", :size => 100 }
        ], :label => "default rule"
      })

      # test missing ROLLOUT condition type with default rule set to 100% off
      split = splits_json[:splits][0]
      split[:conditions][0][:conditionType] = "NOT"
      split[:conditions][0][:matcherGroup][:matchers][0][:matcherType] = "ALL_KEYS"
      expect(split_api.send(:sanitize_feature_flag_elements, [split])[0][:conditions][3]).to eq({
        :conditionType => "ROLLOUT",
        :matcherGroup => {
          :combiner => "AND",
          :matchers => [{
            :keySelector => { :trafficType => "user", :attribute => nil },
            :matcherType => "ALL_KEYS",
            :negate => false,
            :userDefinedSegmentMatcherData => nil,
            :whitelistMatcherData => nil,
            :unaryNumericMatcherData => nil,
            :betweenMatcherData => nil,
            :booleanMatcherData => nil,
            :dependencyMatcherData => nil,
            :stringMatcherData => nil
          }]
        }, :partitions => [
            { :treatment => "on", :size => 0 },
            { :treatment => "off", :size => 100 }
        ], :label => "default rule"
      })
    end
  end
end

def update_splits(iteration, field, value)
  parsed = JSON.parse(File.read(File.expand_path('../../../../test_data/splits/splits_localhost.json', __FILE__)), symbolize_names: true)
  if iteration == -1
    parsed[field] = value
  else
    parsed[:splits][iteration][field] = value
  end

  File.write(File.join(File.expand_path('../../../../test_data/splits/splits_localhost.json', __FILE__)), JSON.dump(parsed))
  sleep 0.2
end
