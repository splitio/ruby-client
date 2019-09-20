module SplitIoClient
  EVENTS_SIZE_THRESHOLD = 32768
  EVENT_AVERAGE_SIZE = 1024

  class SplitClient
    #
    # Creates a new split client instance that connects to split.io API.
    #
    # @param api_key [String] the API key for your split account
    #
    # @return [SplitIoClient] split.io client instance
    def initialize(api_key, adapter = nil, splits_repository, segments_repository, impressions_repository, metrics_repository, events_repository, sdk_blocker, config)
      @api_key = api_key
      @splits_repository = splits_repository
      @segments_repository = segments_repository
      @impressions_repository = impressions_repository
      @metrics_repository = metrics_repository
      @events_repository = events_repository
      @sdk_blocker = sdk_blocker
      @destroyed = false
      @config = config
      @adapter = adapter
    end

    def get_treatment(
        key, split_name, attributes = {}, split_data = nil, store_impressions = true,
        multiple = false, evaluator = nil
      )
      treatment = treatment(key, split_name, attributes, split_data, store_impressions, multiple, evaluator)
      if multiple
         treatment.tap { |t| t.delete(:config) }
      else
        treatment[:treatment]
      end
    end

    def get_treatment_with_config(
        key, split_name, attributes = {}, split_data = nil, store_impressions = true,
        multiple = false, evaluator = nil
      )
      treatment(key, split_name, attributes, split_data, store_impressions, multiple, evaluator, 'get_treatment_with_config')
    end

    def get_treatments(key, split_names, attributes = {})
      treatments = treatments(key, split_names, attributes)
      return treatments if treatments.nil?
      keys = treatments.keys
      treats = treatments.map { |_,t| t[:treatment]  }
      Hash[keys.zip(treats)]
    end

    def get_treatments_with_config(key, split_names, attributes = {})
      treatments(key, split_names, attributes,'get_treatments_with_config')
    end

    def destroy
      @config.logger.info('Split client shutdown started...') if @config.debug_enabled

      @config.threads.select { |name, thread| name.to_s.end_with? 'sender' }.values.each do |thread|
        thread.raise(SplitIoClient::SDKShutdownException)
        thread.join
      end

      @config.threads.values.each { |thread| Thread.kill(thread) }

      @splits_repository.clear
      @segments_repository.clear

      SplitIoClient.load_factory_registry
      SplitIoClient.split_factory_registry.remove(@api_key)

      @config.logger.info('Split client shutdown complete') if @config.debug_enabled
      @config.valid_mode = false
      @destroyed = true
    end

    def store_impression(split_name, matching_key, bucketing_key, treatment, attributes)
      time = (Time.now.to_f * 1000.0).to_i

      @impressions_repository.add(
        matching_key,
        bucketing_key,
        split_name,
        treatment,
        time
      )

      route_impression(split_name, matching_key, bucketing_key, time, treatment, attributes)

    rescue StandardError => error
      @config.log_found_exception(__method__.to_s, error)
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
      @impression_router ||= SplitIoClient::ImpressionRouter.new(@config)
    end

    def track(key, traffic_type_name, event_type, value = nil, properties = nil)
      return false unless valid_client && @config.split_validator.valid_track_parameters(key, traffic_type_name, event_type, value, properties)

      properties_size = EVENT_AVERAGE_SIZE

      if !properties.nil?
        properties, size = validate_properties(properties)
        properties_size += size
        if (properties_size > EVENTS_SIZE_THRESHOLD)
          @config.logger.error("The maximum size allowed for the properties is #{EVENTS_SIZE_THRESHOLD}. Current is #{properties_size}. Event not queued")
          return false
        end
      end

      if ready? && !@config.localhost_mode && !@splits_repository.traffic_type_exists(traffic_type_name)
        @config.logger.warn("track: Traffic Type #{traffic_type_name} " \
          "does not have any corresponding Splits in this environment, make sure you're tracking " \
          'your events to a valid traffic type defined in the Split console')
      end

      begin
        @events_repository.add(key.to_s, traffic_type_name.downcase, event_type.to_s, (Time.now.to_f * 1000).to_i, value, properties, properties_size)
        true
      rescue StandardError => error
        @config.log_found_exception(__method__.to_s, error)
        false
      end
    end

    def keys_from_key(key)
      case key
      when Hash
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
        change_number: treatment_data[:change_number],
        config: treatment_data[:config]
      }
      else
        {
          treatment: treatment_data[:treatment],
          config: treatment_data[:config]
        }
      end
    end

    def sanitize_split_names(calling_method, split_names)
      split_names.compact.uniq.select do |split_name|
        if (split_name.is_a?(String) || split_name.is_a?(Symbol)) && !split_name.empty?
          true
        elsif split_name.is_a?(String) && split_name.empty?
          @config.logger.warn("#{calling_method}: you passed an empty split_name, split_name must be a non-empty String or a Symbol")
          false
        else
          @config.logger.warn("#{calling_method}: you passed an invalid split_name, split_name must be a non-empty String or a Symbol")
          false
        end
      end
    end

    def block_until_ready(time = nil)
      @sdk_blocker.block(time) if @sdk_blocker && !@sdk_blocker.ready?
    end

    private

    def validate_properties(properties)
      properties_count = 0
      size = 0

      fixed_properties = properties.each_with_object({}) { |(key, value), result|

        if(key.is_a?(String) || key.is_a?(Symbol))
          properties_count += 1
          size += variable_size(key)
          if value.is_a?(String) || value.is_a?(Symbol) || value.is_a?(Numeric) || value.is_a?(TrueClass) || value.is_a?(FalseClass) || value.nil?
            result[key] = value
            size += variable_size(value)
          else
            @config.logger.warn("Property #{key} is of invalid type. Setting value to nil")
            result[key] = nil
          end
        end
      }

      @config.logger.warn('Event has more than 300 properties. Some of them will be trimmed when processed') if properties_count > 300

      return fixed_properties, size
    end

    def valid_client
      if @destroyed
        @config.logger.error('Client has already been destroyed - no calls possible')
        return false
      end
      @config.valid_mode
    end

    def treatments(key, split_names, attributes = {}, calling_method = 'get_treatments')
      return nil unless @config.split_validator.valid_get_treatments_parameters(calling_method, split_names)

      sanitized_split_names = sanitize_split_names(calling_method, split_names)

      if sanitized_split_names.empty?
        @config.logger.error("#{calling_method}: split_names must be a non-empty Array")
        return {}
      end

      bucketing_key, matching_key = keys_from_key(key)
      bucketing_key = bucketing_key ? bucketing_key.to_s : nil
      matching_key = matching_key ? matching_key.to_s : nil

      evaluator = Engine::Parser::Evaluator.new(@segments_repository, @splits_repository, @config, true)
      start = Time.now
      treatments_labels_change_numbers =
        @splits_repository.get_splits(sanitized_split_names).each_with_object({}) do |(name, data), memo|
          memo.merge!(name => treatment(key, name, attributes, data, false, true, evaluator))
        end
      latency = (Time.now - start) * 1000.0
      # Measure
      @adapter.metrics.time('sdk.' + calling_method, latency)

      time = (Time.now.to_f * 1000.0).to_i
      @impressions_repository.add_bulk(
        matching_key, bucketing_key, treatments_labels_change_numbers, time
      )

      route_impressions(sanitized_split_names, matching_key, bucketing_key, time, treatments_labels_change_numbers, attributes)

      split_names_keys = treatments_labels_change_numbers.keys
      treatments = treatments_labels_change_numbers.values.map do |v|
        {
          treatment: v[:treatment],
          config: v[:config]
        }
      end
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
    def treatment(
        key, split_name, attributes = {}, split_data = nil, store_impressions = true,
        multiple = false, evaluator = nil, calling_method = 'get_treatment'
      )
      control_treatment = { treatment: Engine::Models::Treatment::CONTROL }

      parsed_control_exception = parsed_treatment(multiple,
        control_treatment.merge({ label: Engine::Models::Label::EXCEPTION }))

      bucketing_key, matching_key = keys_from_key(key)

      return parsed_control_exception unless valid_client && @config.split_validator.valid_get_treatment_parameters(calling_method, key, split_name, matching_key, bucketing_key, attributes)

      bucketing_key = bucketing_key ? bucketing_key.to_s : nil
      matching_key = matching_key.to_s
      sanitized_split_name = split_name.to_s.strip

      if split_name.to_s != sanitized_split_name
        @config.logger.warn("#{calling_method}: split_name #{split_name} has extra whitespace, trimming")
        split_name = sanitized_split_name
      end

      evaluator ||= Engine::Parser::Evaluator.new(@segments_repository, @splits_repository, @config)

      begin
        start = Time.now

        split = multiple ? split_data : @splits_repository.get_split(split_name)

        if split.nil? && ready?
          @config.logger.warn("#{calling_method}: you passed #{split_name} that " \
            'does not exist in this environment, please double check what Splits exist in the web console')

          return parsed_treatment(multiple, control_treatment.merge({ label: Engine::Models::Label::NOT_FOUND }))
        end

        treatment_data =
        if !split.nil? && ready?
          evaluator.call(
            { bucketing_key: bucketing_key, matching_key: matching_key }, split, attributes
          )
        else
          @config.logger.error("#{calling_method}: the SDK is not ready, the operation cannot be executed")

          control_treatment.merge({ label: Engine::Models::Label::NOT_READY })
        end

        latency = (Time.now - start) * 1000.0

        store_impression(split_name, matching_key, bucketing_key, treatment_data, attributes) if store_impressions

        # Measure
        @adapter.metrics.time('sdk.' + calling_method, latency) unless multiple
      rescue StandardError => error
        @config.log_found_exception(__method__.to_s, error)

        store_impression(split_name, matching_key, bucketing_key, control_treatment, attributes) if store_impressions

        return parsed_control_exception
      end

      parsed_treatment(multiple, treatment_data)
    end

    def variable_size(value)
      value.is_a?(String) ? value.length : 0
    end

    def ready?
      return @sdk_blocker.ready? if @sdk_blocker
      true
    end
  end
end
