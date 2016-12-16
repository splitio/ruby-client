module SplitIoClient
  class SplitClient
    #
    # Creates a new split client instance that connects to split.io API.
    #
    # @param api_key [String] the API key for your split account
    #
    # @return [SplitIoClient] split.io client instance
    def initialize(api_key, config = {}, adapter = nil, splits_repository, segments_repository, impressions_repository, metrics_repository)
      @config = config

      @splits_repository = splits_repository
      @segments_repository = segments_repository
      @impressions_repository = impressions_repository
      @metrics_repository = metrics_repository

      @adapter = adapter
    end

    def get_treatments(key, split_names, attributes = nil)
      bucketing_key, matching_key = keys_from_key(key)
      bucketing_key = matching_key if bucketing_key.nil?

      treatments_with_labels =
        @splits_repository.get_splits(split_names).each_with_object({}) do |(name, data), memo|
          memo.merge!(name => get_treatment(key, name, attributes, data, false))
        end

      if @config.impressions_queue_size > 0
        @impressions_repository.add_bulk(matching_key, bucketing_key, treatments_with_labels, (Time.now.to_f * 1000.0).to_i)
      end

      # treatments
    end

    #
    # obtains the treatment for a given feature
    #
    # @param key [String/Hash] user id or hash with matching_key/bucketing_key
    # @param split_name [String/Array] name of the feature that is being validated or array of them
    #
    # @return [String/Hash] Treatment as String or Hash of treatments in case of array of features
    def get_treatment(key, split_name, attributes = nil, split_data = nil, store_impressions = true)
      bucketing_key, matching_key = keys_from_key(key)
      bucketing_key = matching_key if bucketing_key.nil?

      if matching_key.nil?
        @config.logger.warn('matching_key was null for split_name: ' + split_name.to_s)
        return Treatments::CONTROL
      end

      if split_name.nil?
        @config.logger.warn('split_name was null for key: ' + key)
        return Treatments::CONTROL
      end

      start = Time.now
      treatment_with_label = { label: 'exception', treatment: Treatments::CONTROL }

      begin
        split = split_data ? split_data : @splits_repository.get_split(split_name)

        treatment_with_label = if split.nil?
          fail StandardError, "Split with the name of #{split_name} was nil"
        else
          SplitIoClient::Engine::Parser::SplitTreatment.new(@segments_repository).call(
            { bucketing_key: bucketing_key, matching_key: matching_key }, split, attributes
          )
        end
      rescue StandardError => error
        @config.log_found_exception(__method__.to_s, error)
      end

      begin
        latency = (Time.now - start) * 1000.0
        if @config.impressions_queue_size > 0 && store_impressions && split
          # Disable impressions if @config.impressions_queue_size == -1
          @impressions_repository.add(split,
            'key_name' => matching_key,
            'bucketing_key' => bucketing_key,
            'treatment' => treatment_with_label[:treatment],
            'label' => treatment_with_label[:label],
            'time' => (Time.now.to_f * 1000.0).to_i
          )
        end

        # Measure
        @adapter.metrics.time('sdk.get_treatment', latency)
      rescue StandardError => error
        @config.log_found_exception(__method__.to_s, error)
      end

      if split_data
        {
          treatment: treatment_with_label[:treatment],
          label: treatment_with_label[:label]
        }
      else
        treatment_with_label[:treatment]
      end
    end

    def keys_from_key(key)
      case key.class.to_s
      when 'Hash'
        key.values_at(:bucketing_key, :matching_key)
      when 'String'
        [key, key]
      end
    end

    #
    # method that returns the sdk gem version
    #
    # @return [string] version value for this sdk
    def self.sdk_version
      'ruby-'+SplitIoClient::VERSION
    end
  end
end
