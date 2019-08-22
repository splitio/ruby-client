module SplitIoClient
  module Cache
    module Stores
      class LocalhostSplitStore
        attr_reader :splits_repository

        def initialize(splits_repository, config, sdk_blocker = nil)
          @splits_repository = splits_repository
          @config = config
          @sdk_blocker = sdk_blocker

          if @config.using_default_split_file?
            @config.logger.warn('Localhost mode: .split mocks ' \
              'will be deprecated soon in favor of YAML files, which provide more ' \
              'targeting power. Take a look in our documentation.')
          end
        end

        def call
          if ENV['SPLITCLIENT_ENV'] == 'test'
            store_splits
          else
            splits_thread

            if defined?(PhusionPassenger)
              PhusionPassenger.on_event(:starting_worker_process) do |forked|
                splits_thread if forked
              end
            end
          end
        end

        private

        def splits_thread
          @config.threads[:split_store] = Thread.new do
            @config.logger.info('Starting splits fetcher service')
            loop do
              store_splits

              sleep(StoreUtils.random_interval(@config.offline_refresh_rate))
            end
          end
        end

        def store_splits
          load_features.each do |split|
            store_split(split)
          end

          if @sdk_blocker
            @sdk_blocker.splits_ready!
            @sdk_blocker.segments_ready!
          end
        rescue StandardError => error
          @config.logger.error('Error while parsing the split file. Check that the input file matches the expected format')
          @config.log_found_exception(__method__.to_s, error)
        end

        def store_split(split)
          @config.logger.debug("storing split (#{split[:name]})") if @config.debug_enabled

          @splits_repository.add_split(split)
        end

        def load_features
          yaml_extensions = [".yml", ".yaml"]
          if yaml_extensions.include? File.extname(@config.split_file)
            parse_yaml_features
          else
            parse_plain_text_features
          end
        end

        def parse_plain_text_features
          splits = {}

          File.open(@config.split_file).each do |line|
            feature, treatment = line.strip.split(' ')

            next if line.start_with?('#') || line.strip.empty?

            splits[feature] = [{ treatment: treatment }]
          end

          build_splits(splits)
        end

        def parse_yaml_features
          splits = {}

          YAML.load(File.read(@config.split_file)).each do |feature|
            feat_symbolized_keys = feature[feature.keys.first].inject({}){|memo,(k,v)| memo[k.to_sym] = v; memo}

            feat_symbolized_keys[:config] = feat_symbolized_keys[:config].to_json

            if splits[feature.keys.first].nil?
              splits[feature.keys.first] = [feat_symbolized_keys]
            else
              splits[feature.keys.first] << feat_symbolized_keys
            end
          end

          build_splits(splits)
        end

        def build_splits(splits)
          splits.map do |feature, treatments|
            build_split(feature, treatments)
          end
        end

        def build_split(feature, treatments)
          {
            name: feature,
            status: 'ACTIVE',
            killed: false,
            trafficAllocation: 100,
            seed: 2089907429,
            defaultTreatment: 'control_treatment',
            configurations: build_configurations(treatments),
            conditions: build_conditions(treatments)
          }
        end

        def build_configurations(treatments)
          treatments.reduce({}) do |hash, treatment|
            hash.merge(treatment[:treatment].to_sym => treatment[:config])
          end
        end

        def build_conditions(treatments)
          conditions = treatments.map do |treatment|
            if treatment[:keys]
              build_whitelist_treatment(treatment[:treatment], Array(treatment[:keys]))
                .merge(partitions: build_partitions(treatment[:treatment], treatments))
            else
              build_rollout_treatment
                .merge(partitions: build_partitions(treatment[:treatment], treatments))
            end
          end

          conditions.sort_by { |condition| condition[:conditionType]}.reverse!
        end

        def build_whitelist_treatment(treatment_name, whitelist_keys)
          {
            conditionType: 'WHITELIST',
            matcherGroup: {
              combiner: 'AND',
              matchers: [
                {
                  keySelector: nil,
                  matcherType: 'WHITELIST',
                  negate: false,
                  whitelistMatcherData: {
                    whitelist: whitelist_keys
                  }
                }
              ]
            },
            label: "whitelisted #{treatment_name}"
          }
        end

        def build_rollout_treatment
          {
            conditionType: 'ROLLOUT',
            matcherGroup: {
              combiner: 'AND',
              matchers: [
                {
                  matcherType: 'ALL_KEYS',
                  negate: false
                }
              ]
            },
            label: 'default rule'
          }
        end

        def build_partitions(current_treatment_name, treatments)
          treatments.map do |treatment|
            {
              treatment: treatment[:treatment],
              size: treatment[:treatment] == current_treatment_name ? 100 : 0
            }
          end
        end
      end
    end
  end
end
