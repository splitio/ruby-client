module SplitIoClient
  module Cache
    module Senders
      class ImpressionsSender
        def initialize(config)
          @config = config
        end

        def call
          # Disable impressions if @config.impressions_queue_size == -1
          if @config.impressions_queue_size < 0
            @config.logger.info('Disabling impressions service by config')
            return
          end

          @config.logger.info('Starting impressions service...')

          Thread.new do
            loop do
              begin
                post_impressions

                random_interval = randomize_interval(@config.impressions_refresh_rate)
                sleep(random_interval)
              rescue StandardError => error
                @config.log_found_exception(__method__.to_s, error)
              end
            end
          end
          @config.logger.info('Started impressions service')
        end

        private

        #
        # creates the appropriate json data for the cached impressions values
        # and then sends them to the appropriate api endpoint with a valid body format
        #
        # @return [void]
        def post_impressions
          impressions = formatted_impressions

          if impressions.empty?
            @config.logger.debug('No impressions to report') if @config.debug_enabled
            return
          end

          res = post_api('/testImpressions/bulk', impressions)
          if res.status / 100 != 2
            @config.logger.error("Unexpected status code while posting impressions: #{res.status}")
          else
            @config.logger.debug("Impressions reported: #{impressions.length}") if @config.debug_enabled
          end
        end

        # REFACTOR
        def formatted_impressions(impressions = nil)
          impressions_data = impressions || @impressions_repository
          popped_impressions = impressions_data.clear
          test_impression_array = []
          filtered_impressions = []
          keys_treatments_seen = []

          if !popped_impressions.empty?
            popped_impressions.each do |item|
              item_hash = "#{item[:impressions]['key_name']}:#{item[:impressions]['treatment']}"

              next if keys_treatments_seen.include?(item_hash)

              keys_treatments_seen << item_hash
              filtered_impressions << item
            end

            return [] unless filtered_impressions

            features = filtered_impressions.map { |i| i[:feature] }.uniq
            test_impression_array = features.each_with_object([]) do |feature, memo|
              current_impressions = filtered_impressions.select { |i| i[:feature] == feature }
              current_impressions.map! do |i|
                {
                  keyName: i[:impressions]['key_name'],
                  treatment: i[:impressions]['treatment'],
                  time: i[:impressions]['time']
                }
              end

              memo << {
                testName: feature,
                keyImpressions: current_impressions
              }
            end
          end

          test_impression_array
        end

        def randomize_interval(interval)
          @random_generator ||=  Random.new
          random_factor = @random_generator.rand(50..100)/100.0
          interval * random_factor
        end
      end
    end
  end
end
