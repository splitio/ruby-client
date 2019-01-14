# frozen_string_literal: true

module SplitIoClient
  module Validators
    extend self

    def valid_get_treatment_parameters(key, split_name, matching_key, bucketing_key, attributes)
      valid_key?(key) &&
        valid_split_name?(split_name) &&
        valid_matching_key?(matching_key) &&
        valid_bucketing_key?(key, bucketing_key) &&
        valid_attributes?(attributes)
    end

    def valid_get_treatments_parameters(split_names)
      valid_split_names?(split_names)
    end

    def valid_track_parameters(key, traffic_type_name, event_type, value)
      valid_track_key?(key) &&
        valid_traffic_type_name?(traffic_type_name) &&
        valid_event_type?(event_type) &&
        valid_value?(value)
    end

    def valid_split_parameters(split_name)
      valid_split_name?(split_name, :split)
    end

    def valid_matcher_arguments(args)
      return false if !args.key?(:attributes) && !args.key?(:value)
      return false if args.key?(:value) && args[:value].nil?
      return false if args.key?(:attributes) && args[:attributes].nil?
      true
    end

    private

    def string?(value)
      value.is_a?(String) || value.is_a?(Symbol)
    end

    def empty_string?(value)
      value.is_a?(String) && value.empty?
    end

    def number_or_string?(value)
      (value.is_a?(Numeric) && !value.to_f.nan?) || string?(value)
    end

    def log_nil(key, method)
      SplitIoClient.configuration.logger.error("#{method}: you passed a nil #{key}, #{key} must be a non-empty String or a Symbol")
    end

    def log_empty_string(key, method)
      SplitIoClient.configuration.logger.error("#{method}: you passed an empty #{key}, #{key} must be a non-empty String or a Symbol")
    end

    def log_invalid_type(key, method)
      SplitIoClient.configuration.logger.error("#{method}: you passed an invalid #{key} type, #{key} must be a non-empty String or a Symbol")
    end

    def log_convert_numeric(key, method, value)
      SplitIoClient.configuration.logger.warn("#{method}: #{key} \"#{value}\" is not of type String, converting")
    end

    def log_key_too_long(key, method)
      SplitIoClient.configuration.logger.error("#{method}: #{key} is too long - must be #{SplitIoClient.configuration.max_key_size} characters or less")
    end

    def valid_split_name?(split_name, method = :get_treatment)
      if split_name.nil?
        log_nil(:split_name, method)
        return false
      end

      unless string?(split_name)
        log_invalid_type(:split_name, method)
        return false
      end

      if empty_string?(split_name)
        log_empty_string(:split_name, method)
        return false
      end

      true
    end

    def valid_key?(key)
      if key.nil?
        log_nil(:key, :get_treatment)
        return false
      end

      true
    end

    def valid_matching_key?(matching_key)
      if matching_key.nil?
        log_nil(:matching_key, :get_treatment)
        return false
      end

      unless number_or_string?(matching_key)
        log_invalid_type(:matching_key, :get_treatment)
        return false
      end

      if empty_string?(matching_key)
        log_empty_string(:matching_key, :get_treatment)
        return false
      end

      log_convert_numeric(:matching_key, :get_treatment, matching_key) if matching_key.is_a? Numeric

      if matching_key.size > SplitIoClient.configuration.max_key_size
        log_key_too_long(:matching_key, :get_treatment)
        return false
      end

      true
    end

    def valid_bucketing_key?(key, bucketing_key)
      if key.is_a? Hash
        if bucketing_key.nil?
          log_nil(:bucketing_key, :get_treatment)
          return false
        end

        unless number_or_string?(bucketing_key)
          log_invalid_type(:bucketing_key, :get_treatment)
          return false
        end

        if empty_string?(bucketing_key)
          log_empty_string(:bucketing_key, :get_treatment)
          return false
        end

        log_convert_numeric(:bucketing_key, :get_treatment, bucketing_key) if bucketing_key.is_a? Numeric

        if bucketing_key.size > SplitIoClient.configuration.max_key_size
          log_key_too_long(:bucketing_key, :get_treatment)
          return false
        end
      end

      true
    end

    def valid_split_names?(split_names)
      unless !split_names.nil? && split_names.is_a?(Array)
        SplitIoClient.configuration.logger.error('get_treatments: split_names must be a non-empty Array')
        return false
      end

      true
    end

    def valid_attributes?(attributes)
      unless attributes.nil? || attributes.is_a?(Hash)
        SplitIoClient.configuration.logger.error('get_treatment: attributes must be of type Hash')
        return false
      end

      true
    end

    def valid_track_key?(key)
      if key.nil?
        log_nil(:key, :track)
        return false
      end

      unless number_or_string?(key)
        log_invalid_type(:key, :track)
        return false
      end

      if empty_string?(key)
        log_empty_string(:key, :track)
        return false
      end

      log_convert_numeric(:key, :track, key) if key.is_a? Numeric

      if key.size > SplitIoClient.configuration.max_key_size
        log_key_too_long(:key, :track)
        return false
      end

      true
    end

    def valid_event_type?(event_type)
      if event_type.nil?
        log_nil(:event_type, :track)
        return false
      end

      unless string?(event_type)
        log_invalid_type(:event_type, :track)
        return false
      end

      if event_type.empty?
        log_empty_string(:event_type, :track)
        return false
      end

      if (event_type.to_s =~ /^[a-zA-Z0-9][-_.:a-zA-Z0-9]{0,79}$/).nil?
        SplitIoClient.configuration.logger.error("track: you passed '#{event_type}', " \
          'event_type must adhere to the regular expression ^[a-zA-Z0-9][-_.:a-zA-Z0-9]{0,79}$. ' \
          'This means an event name must be alphanumeric, cannot be more than 80 characters long, ' \
          'and can only include a dash, underscore, period, or colon as separators of alphanumeric characters')
        return false
      end

      true
    end

    def valid_traffic_type_name?(traffic_type_name)
      if traffic_type_name.nil?
        log_nil(:traffic_type_name, :track)
        return false
      end

      unless string?(traffic_type_name)
        log_invalid_type(:traffic_type_name, :track)
        return false
      end

      if traffic_type_name.empty?
        log_empty_string(:traffic_type_name, :track)
        return false
      end

      unless traffic_type_name == traffic_type_name.downcase
        SplitIoClient.configuration.logger.warn('track: traffic_type_name should be all lowercase - ' \
          'converting string to lowercase')
      end

      true
    end

    def valid_value?(value)
      unless (value.is_a?(Numeric) && !value.to_f.nan?) || value.nil?
        SplitIoClient.configuration.logger.error('track: value must be Numeric')
        return false
      end

      true
    end
  end
end
