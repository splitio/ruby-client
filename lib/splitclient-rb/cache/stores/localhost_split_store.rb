# frozen_string_literal: true

module SplitIoClient
  module Cache
    module Stores
      class LocalhostSplitStore
        attr_reader :splits_repository

        def initialize(splits_repository, config, sdk_blocker = nil)
          @splits_repository = splits_repository
          @config = config
          @sdk_blocker = sdk_blocker
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

              sleep(StoreUtils.random_interval(@config.features_refresh_rate))
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
          @config.logger.error('Error while parsing the split file. ' \
            'Check that the input file matches the expected format')
          @config.log_found_exception(__method__.to_s, error)
        end

        def store_split(split)
          @config.logger.debug("storing split (#{split[:name]})") if @config.debug_enabled

          @splits_repository.add_split(split)
        end

        def load_features
          yaml_extensions = ['.yml', '.yaml']
          if yaml_extensions.include? File.extname(@config.split_file)
            parse_yaml_features
          else
            @config.logger.warn('Localhost mode: .split mocks ' \
              'will be deprecated soon in favor of YAML files, which provide more ' \
              'targeting power. Take a look in our documentation.')

            parse_plain_text_features
          end
        end

        def parse_plain_text_features
          splits = File.open(@config.split_file).each_with_object({}) do |line, memo|
            feature, treatment = line.strip.split(' ')

            next if line.start_with?('#') || line.strip.empty?

            memo[feature] = [{ treatment: treatment }]
          end

          LocalhostSplitBuilder.build_splits(splits)
        end

        def parse_yaml_features
          splits = YAML.safe_load(File.read(@config.split_file)).each_with_object({}) do |feature, memo|
            feat_symbolized_keys = symbolize_feat_keys(feature)

            feat_name = feature.keys.first

            if memo[feat_name]
              memo[feat_name] << feat_symbolized_keys
            else
              memo[feat_name] = [feat_symbolized_keys]
            end
          end

          LocalhostSplitBuilder.build_splits(splits)
        end

        def symbolize_feat_keys(yaml_feature)
          yaml_feature.values.first.each_with_object({}) do |(k, v), memo|
            memo[k.to_sym] = k == 'config' ? v.to_json : v
          end
        end
      end
    end
  end
end
