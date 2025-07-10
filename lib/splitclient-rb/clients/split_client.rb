module SplitIoClient
  EVENTS_SIZE_THRESHOLD = 32768
  EVENT_AVERAGE_SIZE = 1024
  GET_TREATMENT = 'get_treatment'
  GET_TREATMENTS = 'get_treatments'
  GET_TREATMENT_WITH_CONFIG = 'get_treatment_with_config'
  GET_TREATMENTS_WITH_CONFIG = 'get_treatments_with_config'
  GET_TREATMENTS_BY_FLAG_SET = 'get_treatments_by_flag_set'
  GET_TREATMENTS_BY_FLAG_SETS = 'get_treatments_by_flag_sets'
  GET_TREATMENTS_WITH_CONFIG_BY_FLAG_SET = 'get_treatments_with_config_by_flag_set'
  GET_TREATMENTS_WITH_CONFIG_BY_FLAG_SETS = 'get_treatments_with_config_by_flag_sets'
  TRACK = 'track'

  class SplitClient
    #
    # Creates a new split client instance that connects to split.io API.
    #
    # @param sdk_key [String] the SDK key for your split account
    #
    # @return [SplitIoClient] split.io client instance
    def initialize(sdk_key, repositories, status_manager, config, impressions_manager, telemetry_evaluation_producer, evaluator, split_validator)
      @api_key = sdk_key
      @splits_repository = repositories[:splits]
      @segments_repository = repositories[:segments]
      @rule_based_segments_repository = repositories[:rule_based_segments]
      @impressions_repository = repositories[:impressions]
      @events_repository = repositories[:events]
      @status_manager = status_manager
      @destroyed = false
      @config = config
      @impressions_manager = impressions_manager
      @telemetry_evaluation_producer = telemetry_evaluation_producer
      @split_validator = split_validator
      @evaluator = evaluator
    end

    def get_treatment(
        key, split_name, attributes = {}, evaluation_options = nil, split_data = nil, store_impressions = true,
        multiple = false, evaluator = nil
      )
      result = treatment(key, split_name, attributes, split_data, store_impressions, GET_TREATMENT, multiple, evaluation_options)
      return result.tap { |t| t.delete(:config) } if multiple
      result[:treatment]
    end

    def get_treatment_with_config(
        key, split_name, attributes = {}, evaluation_options = nil, split_data = nil, store_impressions = true,
        multiple = false, evaluator = nil
      )
      treatment(key, split_name, attributes, split_data, store_impressions, GET_TREATMENT_WITH_CONFIG, multiple, evaluation_options)
    end

    def get_treatments(key, split_names, attributes = {}, evaluation_options = nil)
      treatments = treatments(key, split_names, attributes, evaluation_options)

      return treatments if treatments.nil?
      keys = treatments.keys
      treats = treatments.map { |_,t| t[:treatment]  }
      Hash[keys.zip(treats)]
    end

    def get_treatments_with_config(key, split_names, attributes = {}, evaluation_options = nil)
      treatments(key, split_names, attributes, evaluation_options, GET_TREATMENTS_WITH_CONFIG)
    end

    def get_treatments_by_flag_set(key, flag_set, attributes = {}, evaluation_options = nil)
      valid_flag_set = @split_validator.valid_flag_sets(GET_TREATMENTS_BY_FLAG_SET, [flag_set])
      split_names = @splits_repository.get_feature_flags_by_sets(valid_flag_set)
      treatments = treatments(key, split_names, attributes, evaluation_options, GET_TREATMENTS_BY_FLAG_SET)
      return treatments if treatments.nil?
      keys = treatments.keys
      treats = treatments.map { |_,t| t[:treatment]  }
      Hash[keys.zip(treats)]
    end

    def get_treatments_by_flag_sets(key, flag_sets, attributes = {}, evaluation_options = nil)
      valid_flag_set = @split_validator.valid_flag_sets(GET_TREATMENTS_BY_FLAG_SETS, flag_sets)
      split_names = @splits_repository.get_feature_flags_by_sets(valid_flag_set)
      treatments = treatments(key, split_names, attributes, evaluation_options, GET_TREATMENTS_BY_FLAG_SETS)
      return treatments if treatments.nil?
      keys = treatments.keys
      treats = treatments.map { |_,t| t[:treatment]  }
      Hash[keys.zip(treats)]
    end

    def get_treatments_with_config_by_flag_set(key, flag_set, attributes = {}, evaluation_options = nil)
      valid_flag_set = @split_validator.valid_flag_sets(GET_TREATMENTS_WITH_CONFIG_BY_FLAG_SET, [flag_set])
      split_names = @splits_repository.get_feature_flags_by_sets(valid_flag_set)
      treatments(key, split_names, attributes, evaluation_options, GET_TREATMENTS_WITH_CONFIG_BY_FLAG_SET)
    end

    def get_treatments_with_config_by_flag_sets(key, flag_sets, attributes = {}, evaluation_options = nil)
      valid_flag_set = @split_validator.valid_flag_sets(GET_TREATMENTS_WITH_CONFIG_BY_FLAG_SETS, flag_sets)
      split_names = @splits_repository.get_feature_flags_by_sets(valid_flag_set)
      treatments(key, split_names, attributes, evaluation_options, GET_TREATMENTS_WITH_CONFIG_BY_FLAG_SETS)
    end

    def destroy
      @config.logger.info('Split client shutdown started...') if @config.debug_enabled
      if !@config.cache_adapter.is_a?(SplitIoClient::Cache::Adapters::RedisAdapter) && @config.impressions_mode != :none &&
          (!@impressions_repository.empty? || !@events_repository.empty?)
        @config.logger.debug("Impressions and/or Events cache is not empty")
        # Adding small delay to ensure sender threads are fully running
        sleep(0.1)
        if !@config.threads.key?(:impressions_sender) || !@config.threads.key?(:events_sender)
          @config.logger.debug("Periodic data recording thread has not started yet, waiting for service startup.")
          @config.threads[:start_sdk].join(5) if @config.threads.key?(:start_sdk)
        end
      end
      @config.threads.select { |name, thread| name.to_s.end_with? 'sender' }.values.each do |thread|
        thread.raise(SplitIoClient::SDKShutdownException)
        thread.join
      end

      @config.threads.values.each { |thread| Thread.kill(thread) }

      @splits_repository.clear
      @segments_repository.clear
      @rule_based_segments_repository.clear

      SplitIoClient.load_factory_registry
      SplitIoClient.split_factory_registry.remove(@api_key)

      @config.logger.info('Split client shutdown complete') if @config.debug_enabled
      @config.valid_mode = false
      @destroyed = true
    end

    def track(key, traffic_type_name, event_type, value = nil, properties = nil)
      return false unless valid_client && @config.split_validator.valid_track_parameters(key, traffic_type_name, event_type, value, properties)

      start = Time.now
      properties_size = EVENT_AVERAGE_SIZE

      if !properties.nil?
        properties, size = validate_properties(properties)
        properties_size += size
        return false unless check_properties_size(properties_size)
      end

      if ready? && !@config.localhost_mode && !@splits_repository.traffic_type_exists(traffic_type_name)
        @config.logger.warn("track: Traffic Type #{traffic_type_name} " \
          "does not have any corresponding feature flags in this environment, make sure you're tracking " \
          'your events to a valid traffic type defined in the Split user interface')
      end

      @events_repository.add(key.to_s, traffic_type_name.downcase, event_type.to_s, (Time.now.to_f * 1000).to_i, value, properties, properties_size)
      record_latency(TRACK, start)
      true
    rescue StandardError => e
      @config.log_found_exception(__method__.to_s, e)
      record_exception(TRACK)

      false
    end

    def block_until_ready(time = nil)
      @status_manager.wait_until_ready(time) if @status_manager
    end

    private

    def check_properties_size(properties_size, msg = "Event not queued")
      if (properties_size > EVENTS_SIZE_THRESHOLD)
        @config.logger.error("The maximum size allowed for the properties is #{EVENTS_SIZE_THRESHOLD}. Current is #{properties_size}. #{msg}")
        return false
      end
      return true
    end

    def keys_from_key(key)
      case key
      when Hash
        key.values_at(:bucketing_key, :matching_key).map { |k| k.nil? ? nil : k }
      else
        [nil, key].map { |k| k.nil? ? nil : k }
      end
    end

    def parsed_treatment(treatment_data, multiple = false)
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
        config: treatment_data[:config],
      }
      end
    end

    def sanitize_split_names(calling_method, split_names)
      return nil if !split_names.is_a?(Array)

      split_names.compact.uniq.select do |split_name|
        if split_name.nil?
          false
        elsif (split_name.is_a?(String) || split_name.is_a?(Symbol)) && !split_name.empty?
          true
        elsif split_name.is_a?(String) && split_name.empty?
          @config.logger.warn("#{calling_method}: you passed an empty feature_flag_name, flag name must be a non-empty String or a Symbol")
          false
        else
          @config.logger.warn("#{calling_method}: you passed an invalid feature_flag_name, flag name must be a non-empty String or a Symbol")
          false
        end
      end
    end

    def validate_properties(properties, method = 'Event')
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

      @config.logger.warn("#{method} has more than 300 properties. Some of them will be trimmed when processed") if properties_count > 300

      return fixed_properties, size
    end

    def validate_evaluation_options(evaluation_options)
      if !evaluation_options.is_a?(SplitIoClient::Engine::Models::EvaluationOptions)
        @config.logger.warn("Option #{evaluation_options} should be a EvaluationOptions type. Setting value to nil")
        return nil, 0
      end
      evaluation_options.properties = evaluation_options.properties.transform_keys(&:to_sym)
      evaluation_options.properties, size = validate_properties(evaluation_options.properties, method = 'Treatment')
      return evaluation_options, size
    end

    def valid_client
      if @destroyed
        @config.logger.error('Client has already been destroyed - no calls possible')
        return false
      end
      @config.valid_mode
    end

    def treatments(key, feature_flag_names, attributes = {}, evaluation_options = nil, calling_method = 'get_treatments')
      sanitized_feature_flag_names = sanitize_split_names(calling_method, feature_flag_names)

      if sanitized_feature_flag_names.nil?
        @config.logger.error("#{calling_method}: feature_flag_names must be a non-empty Array")
        return nil
      end

      if sanitized_feature_flag_names.empty?
        @config.logger.error("#{calling_method}: feature_flag_names must be a non-empty Array")
        return {}
      end

      bucketing_key, matching_key = keys_from_key(key)
      bucketing_key = bucketing_key ? bucketing_key.to_s : nil
      matching_key = matching_key ? matching_key.to_s : nil
      attributes = parsed_attributes(attributes)

      if !@config.split_validator.valid_get_treatments_parameters(calling_method, key, sanitized_feature_flag_names, matching_key, bucketing_key, attributes)
        to_return = Hash.new
        sanitized_feature_flag_names.each {|name|
          to_return[name.to_sym] = control_treatment_with_config
        }
        return to_return
      end

      if !ready?
        impressions = []
        to_return = Hash.new
        sanitized_feature_flag_names.each {|name|
          to_return[name.to_sym] = control_treatment_with_config
          impressions << { :impression => @impressions_manager.build_impression(matching_key, bucketing_key, name.to_sym, 
                                                               control_treatment_with_config.merge({ :label => Engine::Models::Label::NOT_READY }), false, { attributes: attributes, time: nil },
                                                               evaluation_options), :disabled => false }
        }
        @impressions_manager.track(impressions)
        return to_return
      end

      valid_feature_flag_names = []
      sanitized_feature_flag_names.each { |feature_flag_name|
        valid_feature_flag_names << feature_flag_name unless feature_flag_name.nil?
      }
      start = Time.now

      feature_flags = @splits_repository.splits(valid_feature_flag_names)
      treatments = Hash.new
      invalid_treatments = Hash.new
      feature_flags.each do |key, feature_flag|
        if feature_flag.nil?
          @config.logger.warn("#{calling_method}: you passed #{key} that " \
            'does not exist in this environment, please double check what feature flags exist in the Split user interface')
            invalid_treatments[key] = control_treatment_with_config
          next
        end
        treatments_labels_change_numbers, impressions = evaluate_treatment(feature_flag, key, bucketing_key, matching_key, attributes, calling_method, false, evaluation_options)
        treatments[key] =
        {
          treatment: treatments_labels_change_numbers[:treatment],
          config: treatments_labels_change_numbers[:config]
        }
        @impressions_manager.track(impressions) unless impressions.empty?
      end
      record_latency(calling_method, start)

      treatments.merge(invalid_treatments)
    end

    #
    # obtains the treatment for a given feature
    #
    # @param key [String/Hash] user id or hash with matching_key/bucketing_key
    # @param split_name [String/Array] name of the feature that is being validated or array of them
    # @param attributes [Hash] attributes to pass to the treatment class
    # @param split_data [Hash] split data, when provided this method doesn't fetch splits_repository for the data
    # @param store_impressions [Boolean] impressions aren't stored if this flag is false
    # @return [String/Hash] Treatment as String or Hash of treatments in case of array of features
    def treatment(key, feature_flag_name, attributes = {}, split_data = nil, store_impressions = true,
                   calling_method = 'get_treatment', multiple = false, evaluation_options = nil)
      impressions = []
      bucketing_key, matching_key = keys_from_key(key)

      attributes = parsed_attributes(attributes)

      return parsed_treatment(control_treatment, multiple) unless valid_client && @config.split_validator.valid_get_treatment_parameters(calling_method, key, feature_flag_name, matching_key, bucketing_key, attributes)

      bucketing_key = bucketing_key ? bucketing_key.to_s : nil
      matching_key = matching_key.to_s
      sanitized_feature_flag_name = feature_flag_name.to_s.strip

      if feature_flag_name.to_s != sanitized_feature_flag_name
        @config.logger.warn("#{calling_method}: feature_flag_name #{feature_flag_name} has extra whitespace, trimming")
        feature_flag_name = sanitized_feature_flag_name
      end

      feature_flag = @splits_repository.get_split(feature_flag_name)
      treatments, impressions_decorator = evaluate_treatment(feature_flag, feature_flag_name, bucketing_key, matching_key, attributes, calling_method, multiple, evaluation_options)

      @impressions_manager.track(impressions_decorator) unless impressions_decorator.nil?
      treatments
    end

    def evaluate_treatment(feature_flag, feature_flag_name, bucketing_key, matching_key, attributes, calling_method, multiple = false, evaluation_options = nil)
      impressions_decorator = []
      begin
        start = Time.now
        if feature_flag.nil? && ready?
          @config.logger.warn("#{calling_method}: you passed #{feature_flag_name} that " \
            'does not exist in this environment, please double check what feature flags exist in the Split user interface')
          return parsed_treatment(control_treatment.merge({ :label => Engine::Models::Label::NOT_FOUND }), multiple), nil
        end

        if !feature_flag.nil? && ready?
          treatment_data = @evaluator.evaluate_feature_flag(
            { bucketing_key: bucketing_key, matching_key: matching_key }, feature_flag, attributes
          )
          impressions_disabled = feature_flag[:impressionsDisabled]
        else
          @config.logger.error("#{calling_method}: the SDK is not ready, results may be incorrect for feature flag #{feature_flag_name}. Make sure to wait for SDK readiness before using this method.")
          treatment_data = control_treatment.merge({ :label => Engine::Models::Label::NOT_READY })
          impressions_disabled = false
        end

        evaluation_options, size = validate_evaluation_options(evaluation_options) unless evaluation_options.nil?
        evaluation_options.properties = nil unless evaluation_options.nil? or check_properties_size((EVENT_AVERAGE_SIZE + size), "Properties are ignored")

        record_latency(calling_method, start)
        impression_decorator = { :impression => @impressions_manager.build_impression(matching_key, bucketing_key, feature_flag_name, treatment_data, impressions_disabled, { attributes: attributes, time: nil }, evaluation_options), :disabled => impressions_disabled }
        impressions_decorator << impression_decorator unless impression_decorator.nil?
      rescue StandardError => e
        @config.log_found_exception(__method__.to_s, e)
        record_exception(calling_method)
        impression_decorator = { :impression => @impressions_manager.build_impression(matching_key, bucketing_key, feature_flag_name, control_treatment, false, { attributes: attributes, time: nil }, evaluation_options), :disabled => false }
        impressions_decorator << impression_decorator unless impression_decorator.nil?

        return parsed_treatment(control_treatment.merge({ :label => Engine::Models::Label::EXCEPTION }), multiple), impressions_decorator
      end
      return parsed_treatment(treatment_data, multiple), impressions_decorator
    end

    def control_treatment
      { :treatment => Engine::Models::Treatment::CONTROL }
    end

    def control_treatment_with_config
      {:treatment => Engine::Models::Treatment::CONTROL, :config => nil}
    end

    def variable_size(value)
      value.is_a?(String) ? value.length : 0
    end

    def ready?
      return @status_manager.ready? if @status_manager
      true
    end

    def parsed_attributes(attributes)
      return attributes || attributes.to_h
    end

    def record_latency(method, start)
      bucket = BinarySearchLatencyTracker.get_bucket((Time.now - start) * 1000.0)

      case method
      when GET_TREATMENT
        @telemetry_evaluation_producer.record_latency(Telemetry::Domain::Constants::TREATMENT, bucket)
      when GET_TREATMENTS
        @telemetry_evaluation_producer.record_latency(Telemetry::Domain::Constants::TREATMENTS, bucket)
      when GET_TREATMENT_WITH_CONFIG
        @telemetry_evaluation_producer.record_latency(Telemetry::Domain::Constants::TREATMENT_WITH_CONFIG, bucket)
      when GET_TREATMENTS_WITH_CONFIG
        @telemetry_evaluation_producer.record_latency(Telemetry::Domain::Constants::TREATMENTS_WITH_CONFIG, bucket)
      when GET_TREATMENTS_BY_FLAG_SET
        @telemetry_evaluation_producer.record_latency(Telemetry::Domain::Constants::TREATMENTS_BY_FLAG_SET, bucket)
      when GET_TREATMENTS_BY_FLAG_SETS
        @telemetry_evaluation_producer.record_latency(Telemetry::Domain::Constants::TREATMENTS_BY_FLAG_SETS, bucket)
      when GET_TREATMENTS_WITH_CONFIG_BY_FLAG_SET
        @telemetry_evaluation_producer.record_latency(Telemetry::Domain::Constants::TREATMENTS_WITH_CONFIG_BY_FLAG_SET, bucket)
      when GET_TREATMENTS_WITH_CONFIG_BY_FLAG_SETS
        @telemetry_evaluation_producer.record_latency(Telemetry::Domain::Constants::TREATMENTS_WITH_CONFIG_BY_FLAG_SETS, bucket)
      when TRACK
        @telemetry_evaluation_producer.record_latency(Telemetry::Domain::Constants::TRACK, bucket)
      end
    end

    def record_exception(method)
      case method
      when GET_TREATMENT
        @telemetry_evaluation_producer.record_exception(Telemetry::Domain::Constants::TREATMENT)
      when GET_TREATMENTS
        @telemetry_evaluation_producer.record_exception(Telemetry::Domain::Constants::TREATMENTS)
      when GET_TREATMENT_WITH_CONFIG
        @telemetry_evaluation_producer.record_exception(Telemetry::Domain::Constants::TREATMENT_WITH_CONFIG)
      when GET_TREATMENTS_WITH_CONFIG
        @telemetry_evaluation_producer.record_exception(Telemetry::Domain::Constants::TREATMENTS_WITH_CONFIG)
      when GET_TREATMENTS_BY_FLAG_SET
        @telemetry_evaluation_producer.record_exception(Telemetry::Domain::Constants::TREATMENTS_BY_FLAG_SET)
      when GET_TREATMENTS_BY_FLAG_SETS
        @telemetry_evaluation_producer.record_exception(Telemetry::Domain::Constants::TREATMENTS_BY_FLAG_SETS)
      when GET_TREATMENTS_WITH_CONFIG_BY_FLAG_SET
        @telemetry_evaluation_producer.record_exception(Telemetry::Domain::Constants::TREATMENTS_WITH_CONFIG_BY_FLAG_SET)
      when GET_TREATMENTS_WITH_CONFIG_BY_FLAG_SETS
        @telemetry_evaluation_producer.record_exception(Telemetry::Domain::Constants::TREATMENTS_WITH_CONFIG_BY_FLAG_SETS)
      when TRACK
        @telemetry_evaluation_producer.record_exception(Telemetry::Domain::Constants::TRACK)
      end
    end
  end
end
