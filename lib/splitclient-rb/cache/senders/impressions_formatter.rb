# frozen_string_literal: true

module SplitIoClient
  module Cache
    module Senders
      class ImpressionsFormatter
        def initialize(impressions_repository)
          @impressions_repository = impressions_repository
        end

        def call(fetch_all_impressions, raw_impressions = nil)
          impressions = raw_impressions || (fetch_all_impressions ? @impressions_repository.clear : @impressions_repository.batch)
          
          filtered_impressions = filter_impressions(impressions)

          return [] if impressions.empty? || filtered_impressions.empty?

          formatted_impressions = unique_features(filtered_impressions).each_with_object([]) do |feature, memo|
            feature_impressions = feature_impressions(filtered_impressions, feature)
            ip = feature_impressions.first[:m][:i]
            current_impressions = current_impressions(feature_impressions)
            memo << {
              testName: feature.to_sym,
              keyImpressions: current_impressions,
              ip: ip
            }
          end

          formatted_impressions
        end

        private

        def feature_impressions(filtered_impressions, feature)
          filtered_impressions.select do |impression|
            impression[:i][:f] == feature
          end
        end

        def current_impressions(feature_impressions)
          feature_impressions.map do |impression|
            {
              keyName: impression[:i][:k],
              treatment: impression[:i][:t],
              time: impression[:i][:m],
              bucketingKey: impression[:i][:b],
              label: impression[:i][:r],
              changeNumber: impression[:i][:c],
              previousTime: impression[:i][:pt]
            }
          end
        end

        def unique_features(impressions)
          impressions.map { |impression| impression[:i][:f] }.uniq
        end

        # Filter seen impressions by impression_hash
        def filter_impressions(unfiltered_impressions)
          impressions_seen = []

          unfiltered_impressions.each_with_object([]) do |impression, impressions|
            impression_hash = impression_hash(impression)

            next if impressions_seen.include?(impression_hash)

            impressions_seen << impression_hash
            impressions << impression
          end
        end

        def impression_hash(impression)
          "#{impression[:i][:f]}:" \
          "#{impression[:i][:k]}:" \
          "#{impression[:i][:b]}:" \
          "#{impression[:i][:c]}:" \
          "#{impression[:i][:t]}:" \
          "#{impression[:i][:pt]}"
        end
      end
    end
  end
end
