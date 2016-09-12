module SplitIoClient
  module Stores
    class SplitStore
      def initialize(adapter, config, api_key)
        @cache = SplitIoClient::Cache::Split.new(adapter)
        @config = config
        @parsed_splits = SplitParser.new(@config.logger)
        @api_key = api_key
      end

      def call
        Thread.new do
          loop do
            begin
              data = splits_since(@parsed_splits.since)

              if data
                data[:splits].each do |split|
                  @cache << SplitIoClient::Split.new(split).to_h
                end
              end

              if @parsed_splits.empty?
                # FIXME
                @parsed_splits.splits = splits_arr
              else
                refresh_splits(splits_arr)
              end
              @parsed_splits.since = data[:till]

              sleep(random_interval)
            rescue StandardError => error
              @config.log_found_exception(__method__.to_s, error)
            end
          end
        end
      end

      private

      def random_interval
        interval = @config.features_refresh_rate
        random_factor = Random.new.rand(50..100) / 100.0

        interval * random_factor
      end

      def refresh_splits(splits_arr)
        feature_names = splits_arr.map { |s| s.name }
        @parsed_splits.splits.delete_if { |sp| feature_names.include?(sp.name) }
        @parsed_splits.splits += splits_arr
      end

      def splits_since(since)
        SplitIoClient::Api::Splits.new(@api_key, @config).since(since)
      end
    end
  end
end
