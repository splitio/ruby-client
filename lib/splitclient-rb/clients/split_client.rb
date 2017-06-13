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
      evaluator = Engine::Parser::Evaluator.new(@segments_repository, @splits_repository, true)

      treatments_labels_change_numbers =
        @splits_repository.get_splits(split_names).each_with_object({}) do |(name, data), memo|
          memo.merge!(name => get_treatment(key, name, attributes, data, false, true, evaluator))
        end

      if @config.impressions_queue_size > 0
        @impressions_repository.add_bulk(
          matching_key, bucketing_key, treatments_labels_change_numbers, (Time.now.to_f * 1000.0).to_i
        )

        route_impressions(split_names, matching_key, bucketing_key, treatments_labels_change_numbers, attributes)
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
    # @param evaluator [Evaluator] Evaluator class instance, used to cache treatments
    #
    # @return [String/Hash] Treatment as String or Hash of treatments in case of array of features
    def get_treatment(
        key, split_name, attributes = nil, split_data = nil, store_impressions = true,
        multiple = false, evaluator = nil
      )
      bucketing_key, matching_key = keys_from_key(key)
      treatment_data = { label: Engine::Models::Label::EXCEPTION, treatment: SplitIoClient::Engine::Models::Treatment::CONTROL }
      evaluator ||= Engine::Parser::Evaluator.new(@segments_repository, @splits_repository)

      if matching_key.nil?
        @config.logger.warn('matching_key was null for split_name: ' + split_name.to_s)
        return parsed_treatment(multiple, treatment_data)
      end

      if split_name.nil?
        @config.logger.warn('split_name was null for key: ' + key)
        return parsed_treatment(multiple, treatment_data)
      end

      start = Time.now

      begin
        split = multiple ? split_data : @splits_repository.get_split(split_name)

        if split.nil?
          @config.logger.debug("split_name: #{split_name} does not exist. Returning CONTROL")
          return parsed_treatment(multiple, treatment_data)
        else
          treatment_data =
            evaluator.call(
            { bucketing_key: bucketing_key, matching_key: matching_key }, split, attributes
          )
        end
      rescue StandardError => error
        @config.log_found_exception(__method__.to_s, error)

        store_impression(
          split_name, matching_key, bucketing_key,
          { treatment: SplitIoClient::Engine::Models::Treatment::CONTROL, label: SplitIoClient::Engine::Models::Label::EXCEPTION },
          store_impressions, attributes
        )

        return parsed_treatment(multiple, treatment_data)
      end

      begin
        latency = (Time.now - start) * 1000.0
        # Disable impressions if @config.impressions_queue_size == -1
        split && store_impression(split_name, matching_key, bucketing_key, treatment_data, store_impressions, attributes)

        # Measure
        @adapter.metrics.time('sdk.get_treatment', latency)
      rescue StandardError => error
        @config.log_found_exception(__method__.to_s, error)

        store_impression(
          split_name, matching_key, bucketing_key,
          { treatment: SplitIoClient::Engine::Models::Treatment::CONTROL, label: SplitIoClient::Engine::Models::Label::EXCEPTION },
          store_impressions, attributes
        )

        return parsed_treatment(multiple, treatment_data)
      end

      parsed_treatment(multiple, treatment_data)
    end

    def destroy
      @config.logger.info('Destroying split client')

      @config.threads.each do |name, thread|
        Thread.kill(thread)
      end

      @impressions_repository.clear
      @metrics_repository.clear
      @splits_repository.clear
      @segments_repository.clear
    end

    def store_impression(split_name, matching_key, bucketing_key, treatment, store_impressions, attributes)
      route_impression(split_name, matching_key, bucketing_key, treatment, attributes) if @config.impression_listener && store_impressions

      return if @config.impressions_queue_size <= 0 || !store_impressions

      @impressions_repository.add(split_name,
        'keyName' => matching_key,
        'bucketingKey' => bucketing_key,
        'treatment' => treatment[:treatment],
        'label' => @config.labels_enabled ? treatment[:label] : nil,
        'time' => (Time.now.to_f * 1000.0).to_i,
        'changeNumber' => treatment[:change_number]
      )
    end

    def route_impression(split_name, matching_key, bucketing_key, treatment, attributes)
      impression_router.add(
        split_name: split_name,
        matching_key: matching_key,
        bucketing_key: bucketing_key,
        treatment: treatment,
        attributes: attributes
      )
    end

    def route_impressions(split_names, matching_key, bucketing_key, treatments_labels_change_numbers, attributes)
      impression_router.add_bulk(
        split_names: split_names,
        matching_key: matching_key,
        bucketing_key: bucketing_key,
        treatments_labels_change_numbers: treatments_labels_change_numbers,
        attributes: attributes
      )
    end

    def impression_router
      @impression_router ||= SplitIoClient::ImpressionRouter.new(@config)
    end

    def keys_from_key(key)
      case key.class.to_s
      when 'Hash'
        key.values_at(:bucketing_key, :matching_key).map { |k| k.nil? ? nil : k.to_s }
      else
        [nil, key].map { |k| k.nil? ? nil : k.to_s }
      end
    end

    def parsed_treatment(multiple, treatment_data)
      if multiple
        {
          treatment: treatment_data[:treatment],
          label: treatment_data[:label],
          change_number: treatment_data[:change_number]
        }
      else
        treatment_data[:treatment]
      end
    end
  end
end
