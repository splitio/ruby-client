module SplitIoClient
  module Cache
    module Senders
      class ImpressionsFormatter
        def initialize(impressions_repository)
          @impressions_repository = impressions_repository
        end

        def call(raw_impressions)
          impressions = raw_impressions ? raw_impressions : @impressions_repository.clear
          formatted_impressions = []
          filtered_impressions = filter_impressions(impressions)

          return [] if impressions.empty? || filtered_impressions.empty?

          formatted_impressions = unique_features(filtered_impressions).each_with_object([]) do |feature, memo|
            ip = nil
            current_impressions =
              filtered_impressions
                .select { |impression| impression[:feature] == feature }
                .map do |impression|
                  ip = impression[:ip]
                  {
                    keyName: impression[:impressions]['keyName'] || impression[:impressions]['key_name'],
                    treatment: impression[:impressions]['treatment'],
                    time: impression[:impressions]['time'],
                    bucketingKey: impression[:impressions]['bucketingKey'] || impression[:impressions]['bucketing_key'],
                    label: impression[:impressions]['label'],
                    changeNumber: impression[:impressions]['changeNumber'] || impression[:impressions]['change_number'],
                  }
                end

            memo << {
              testName: feature,
              keyImpressions: current_impressions,
              ip: ip
            }
          end

          formatted_impressions
        end

        private

        def unique_features(impressions)
          impressions.map { |impression| impression[:feature] }.uniq
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
          "#{impression[:feature]}:" \
          "#{impression[:impressions]['keyName']}:" \
          "#{impression[:impressions]['bucketingKey']}:" \
          "#{impression[:impressions]['changeNumber']}:" \
          "#{impression[:impressions]['treatment']}"
        end
      end
    end
  end
end
