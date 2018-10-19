module SplitIoClient
  module Validators
    extend self

    def valid_get_treatment_parameters(key, split_name, matching_key, bucketing_key)
      valid_key?(key) && valid_split_name?(split_name) && valid_matching_key?(matching_key) && valid_bucketing_key?(bucketing_key)
    end

    def valid_get_treatments_parameters(split_names)
      valid_split_names?(split_names)
    end

    def valid_track_parameters(key, traffic_type_name, event_type, value)
      valid_track_key?(key) && valid_traffic_type_name?(traffic_type_name) && valid_event_type?(event_type) && valid_value?(value)
    end

    def valid_split_parameters(split_name)
      valid_split_name?(split_name, :split)
    end

    private

    def string?(value)
      value.is_a?(String) || value.is_a?(Symbol)
    end

    def number_or_string?(value)
      value.is_a?(Numeric) || string?(value)
    end

    def log_nil(key, method)
      SplitIoClient.configuration.logger.error("#{method}: #{key} cannot be nil")
    end

    def log_string(key, method)
      SplitIoClient.configuration.logger.error("#{method}: #{key} must be a String or a Symbol")
    end

    def log_number_or_string(key, method)
      SplitIoClient.configuration.logger.error("#{method}: #{key} must be a String")
    end

    def log_convert_numeric(key, method)
      SplitIoClient.configuration.logger.warn("#{method}: #{key} is not of type String, converting to String")
    end

    def valid_split_name?(split_name, method=:get_treatment)
      if split_name.nil?
        log_nil(:split_name, method)
        return false
      end

      unless string?(split_name)
        log_string(:split_name, method)
        return false
      end

      return true
    end

    def valid_key?(key)
      if key.nil?
        log_nil(:key, :get_treatment)
        return false
      end

      return true
    end

    def valid_matching_key?(matching_key)
      if matching_key.nil?
        log_nil(:matching_key, :get_treatment)
        return false
      end

      unless number_or_string?(matching_key)
        log_number_or_string(:matching_key, :get_treatment)
        return false
      end

      if matching_key.is_a? Numeric
        log_convert_numeric(:matching_key, :get_treatment)
      end

      return true
    end

    def valid_bucketing_key?(bucketing_key)
      if bucketing_key.nil?
        SplitIoClient.configuration.logger.warn('get_treatment: key object should have bucketing_key set')
        return true
      end

      unless number_or_string?(bucketing_key)
        log_number_or_string(:bucketing_key, :get_treatment)
        return false
      end

      if bucketing_key.is_a? Numeric
        log_convert_numeric(:bucketing_key, :get_treatment)
      end

      return true
    end

    def valid_split_names?(split_names)
      if split_names.nil?
        log_nil(:split_names, :get_treatments)
        return false
      end

      unless split_names.is_a? Array
        SplitIoClient.configuration.logger.warn('get_treatments: split_names must be an Array')
        return false
      end

      return true
    end

    def valid_track_key?(key)
      if key.nil?
        log_nil(:key, :track)
        return false
      end

      unless number_or_string?(key)
        log_number_or_string(:key, :track)
        return false
      end

      if key.is_a? Numeric
        log_convert_numeric(:key, :track)
      end

      return true
    end

    def valid_event_type?(event_type)
      if event_type.nil?
        log_nil(:event_type, :track)
        return false
      end

      unless string?(event_type)
        log_string(:event_type, :track)
        return false
      end

      if (event_type.to_s =~ /[a-zA-Z0-9][-_\.a-zA-Z0-9]{0,62}/).nil?
        SplitIoClient.configuration.logger.error('track: event_type must adhere to [a-zA-Z0-9][-_\.a-zA-Z0-9]{0,62}')
        return false
      end

      return true
    end

    def valid_traffic_type_name?(traffic_type_name)
      if traffic_type_name.nil?
        log_nil(:traffic_type_name, :track)
        return false
      end

      unless string?(traffic_type_name)
        log_string(:traffic_type_name, :track)
        return false
      end

      if traffic_type_name.empty?
        SplitIoClient.configuration.logger.error('track: traffic_type_name must not be an empty String')
        return false
      end

      return true
    end

    def valid_value?(value)
      unless value.is_a?(Numeric) || value.nil?
        SplitIoClient.configuration.logger.error('track: value must be a number')
        return false
      end

      return true
    end
  end
end
