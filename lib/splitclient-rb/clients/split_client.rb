module SplitIoClient

  class SplitClient
    #
    # Creates a new split client instance that connects to split.io API.
    #
    # @param api_key [String] the API key for your split account
    #
    # @return [SplitIoClient] split.io client instance
    def initialize(api_key, adapter = nil, splits_repository, segments_repository, impressions_repository, metrics_repository, events_repository)
      @splits_repository = splits_repository
      @segments_repository = segments_repository
      @impressions_repository = impressions_repository
      @metrics_repository = metrics_repository
      @events_repository = events_repository

      @adapter = adapter
    end

    def get_treatments(key, split_names, attributes = {})

      return nil unless SplitIoClient::Validators.valid_get_treatments_parameters(split_names)

      sanitized_split_names = sanitize_split_names(split_names)

      if sanitized_split_names.empty?
        SplitIoClient.configuration.logger.warn('get_treatments: split_names is an empty array or has null values')
        return {}
      end

      bucketing_key, matching_key = keys_from_key(key)
      bucketing_key = bucketing_key ? bucketing_key.to_s : nil
      matching_key = matching_key ? matching_key.to_s : nil

      evaluator = Engine::Parser::Evaluator.new(@segments_repository, @splits_repository, true)
      start = Time.now
      treatments_labels_change_numbers =
        @splits_repository.get_splits(sanitized_split_names).each_with_object({}) do |(name, data), memo|
          memo.merge!(name => get_treatment(key, name, attributes, data, false, true, evaluator))
        end
      latency = (Time.now - start) * 1000.0
      # Measure
      @adapter.metrics.time('sdk.get_treatments', latency)

      unless SplitIoClient.configuration.disable_impressions
        time = (Time.now.to_f * 1000.0).to_i
        @impressions_repository.add_bulk(
          matching_key, bucketing_key, treatments_labels_change_numbers, time
        )

        route_impressions(sanitized_split_names, matching_key, bucketing_key, time, treatments_labels_change_numbers, attributes)
      end

      split_names_keys = treatments_labels_change_numbers.keys
      treatments = treatments_labels_change_numbers.values.map { |v| v[:treatment] }

      Hash[split_names_keys.zip(treatments)]
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
        key, split_name, attributes = {}, split_data = nil, store_impressions = true,
        multiple = false, evaluator = nil
      )
      control_treatment = { label: Engine::Models::Label::EXCEPTION, treatment: SplitIoClient::Engine::Models::Treatment::CONTROL }
      parsed_control_treatment = parsed_treatment(multiple, control_treatment)

      bucketing_key, matching_key = keys_from_key(key)

      return parsed_control_treatment unless SplitIoClient::Validators.valid_get_treatment_parameters(key, split_name, matching_key, bucketing_key)

      bucketing_key = bucketing_key ? bucketing_key.to_s : nil
      matching_key = matching_key.to_s
      evaluator ||= Engine::Parser::Evaluator.new(@segments_repository, @splits_repository)

      begin
        start = Time.now

        split = multiple ? split_data : @splits_repository.get_split(split_name)

        if split.nil?
          SplitIoClient.configuration.logger.warn("split_name: #{split_name} does not exist. Returning CONTROL")
          return parsed_control_treatment
        end

        treatment_data =
          evaluator.call(
          { bucketing_key: bucketing_key, matching_key: matching_key }, split, attributes
        )

        latency = (Time.now - start) * 1000.0
        store_impression(split_name, matching_key, bucketing_key, treatment_data, store_impressions, attributes)

        # Measure
        @adapter.metrics.time('sdk.get_treatment', latency) unless multiple
      rescue StandardError => error
        SplitIoClient.configuration.log_found_exception(__method__.to_s, error)

        store_impression(split_name, matching_key, bucketing_key, control_treatment, store_impressions, attributes)

        return parsed_control_treatment
      end

      parsed_treatment(multiple, treatment_data)
    end

    def destroy
      SplitIoClient.configuration.logger.info('Split client shutdown started...') if SplitIoClient.configuration.debug_enabled

      SplitIoClient.configuration.threads[:impressions_sender].raise(SplitIoClient::ImpressionShutdownException)
      SplitIoClient.configuration.threads.reject { |k, _| k == :impressions_sender }.each do |name, thread|
        Thread.kill(thread)
      end

      @metrics_repository.clear
      @splits_repository.clear
      @segments_repository.clear
      @events_repository.clear

      SplitIoClient.configuration.logger.info('Split client shutdown complete') if SplitIoClient.configuration.debug_enabled
    end

    def store_impression(split_name, matching_key, bucketing_key, treatment, store_impressions, attributes)
      time = (Time.now.to_f * 1000.0).to_i

      return if SplitIoClient.configuration.disable_impressions || !store_impressions

      @impressions_repository.add(
        matching_key,
        bucketing_key,
        split_name,
        treatment,
        time
      )

      route_impression(split_name, matching_key, bucketing_key, time, treatment, attributes)

    rescue StandardError => error
      SplitIoClient.configuration.log_found_exception(__method__.to_s, error)
    end

    def route_impression(split_name, matching_key, bucketing_key, time, treatment, attributes)
      impression_router.add(
        split_name: split_name,
        matching_key: matching_key,
        bucketing_key: bucketing_key,
        time: time,
        treatment: treatment,
        attributes: attributes
      )
    end

    def route_impressions(split_names, matching_key, bucketing_key, time, treatments_labels_change_numbers, attributes)
      impression_router.add_bulk(
        split_names: split_names,
        matching_key: matching_key,
        bucketing_key: bucketing_key,
        time: time,
        treatments_labels_change_numbers: treatments_labels_change_numbers,
        attributes: attributes
      )
    end

    def impression_router
      @impression_router ||= SplitIoClient::ImpressionRouter.new
    end

    def track(key, traffic_type_name, event_type, value = nil)
      return false unless SplitIoClient::Validators.valid_track_parameters(key, traffic_type_name, event_type, value)
      begin
        @events_repository.add(key.to_s, traffic_type_name, event_type.to_s, (Time.now.to_f * 1000).to_i, value)
        true
      rescue StandardError => error
        SplitIoClient.configuration.log_found_exception(__method__.to_s, error)
        false
      end
    end

    def keys_from_key(key)
      case key.class.to_s
      when 'Hash'
        key.values_at(:bucketing_key, :matching_key).map { |k| k.nil? ? nil : k }
      else
        [nil, key].map { |k| k.nil? ? nil : k }
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

    def sanitize_split_names(split_names)
      split_names.compact.uniq.select do |split_name|
        if split_name.is_a?(String) && !split_name.empty?
          true
        else
          SplitIoClient.configuration.logger.warn('get_treatments: split_name has to be a non empty string')
          false
        end
      end
    end
  end
end
