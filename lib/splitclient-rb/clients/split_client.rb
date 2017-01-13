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

      treatments_labels_change_numbers =
        @splits_repository.get_splits(split_names).each_with_object({}) do |(name, data), memo|
          memo.merge!(name => get_treatment(key, name, attributes, data, false, true))
        end

      if @config.impressions_queue_size > 0
        @impressions_repository.add_bulk(matching_key, bucketing_key, treatments_labels_change_numbers, (Time.now.to_f * 1000.0).to_i)
      end

      split_names = treatments_labels_change_numbers.keys
      treatments = treatments_labels_change_numbers.values.map { |v| v[:treatment] }

      Hash[split_names.zip(treatments)]
    end

    #
    # obtains the treatment for a given feature
    #
    # @param key [String/Hash] user id or hash with matching_key/bucketing_key
    # @param split_name [String/Array] name of the feature that is being validated or array of them
    # @param attributes [Hash] attributes to pass to the treatment class
    # @param split_data [Hash] split data, when provided this method doesn't fetch splits_repository for the data
    # @param store_impressions [Boolean] impressions aren't stored if this flag is false
    # @param multiple [Hash] internal flag to signal if method is called by get_treatments
    #
    # @return [String/Hash] Treatment as String or Hash of treatments in case of array of features
    def get_treatment(key, split_name, attributes = nil, split_data = nil, store_impressions = true, multiple = false)
      bucketing_key, matching_key = keys_from_key(key)

      if matching_key.nil?
        @config.logger.warn('matching_key was null for split_name: ' + split_name.to_s)
        return parsed_treatment(multiple, { label: Engine::Models::Label::EXCEPTION, treatment: Treatments::CONTROL })
      end

      if split_name.nil?
        @config.logger.warn('split_name was null for key: ' + key)
        return parsed_treatment(multiple, { label: Engine::Models::Label::EXCEPTION, treatment: Treatments::CONTROL })
      end

      start = Time.now
      treatment_label_change_number = { label: Engine::Models::Label::EXCEPTION, treatment: Treatments::CONTROL }

      begin
        split = multiple ? split_data : @splits_repository.get_split(split_name)

        if split.nil?
          return parsed_treatment(multiple, treatment_label_change_number)
        else
          treatment_label_change_number = SplitIoClient::Engine::Parser::SplitTreatment.new(@segments_repository).call(
            { bucketing_key: bucketing_key, matching_key: matching_key }, split, attributes
          )
        end
      rescue StandardError => error
        @config.log_found_exception(__method__.to_s, error)

        return parsed_treatment(multiple, treatment_label_change_number)
      end

      begin
        latency = (Time.now - start) * 1000.0
        if @config.impressions_queue_size > 0 && store_impressions && split
          # Disable impressions if @config.impressions_queue_size == -1
          @impressions_repository.add(split_name,
            'key_name' => matching_key,
            'bucketing_key' => bucketing_key,
            'treatment' => treatment_label_change_number[:treatment],
            'label' => @config.labels_enabled ? treatment_label_change_number[:label] : nil,
            'time' => (Time.now.to_f * 1000.0).to_i,
            'change_number' => treatment_label_change_number[:change_number]
          )
        end

        # Measure
        @adapter.metrics.time('sdk.get_treatment', latency)
      rescue StandardError => error
        @config.log_found_exception(__method__.to_s, error)

        return parsed_treatment(multiple, treatment_label_change_number)
      end

      parsed_treatment(multiple, treatment_label_change_number)
    end

    def keys_from_key(key)
      case key.class.to_s
      when 'Hash'
        key.values_at(:bucketing_key, :matching_key)
      when 'String'
        [nil, key]
      end
    end

    def parsed_treatment(multiple, treatment_label_change_number)
      if multiple
        {
          treatment: treatment_label_change_number[:treatment],
          label: treatment_label_change_number[:label],
          change_number: treatment_label_change_number[:change_number]
        }
      else
        treatment_label_change_number[:treatment]
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
