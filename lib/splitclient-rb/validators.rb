# frozen_string_literal: true
require 'set'

module SplitIoClient
  class Validators

    Flagset_regex = /^[a-z0-9][_a-z0-9]{0,49}$/

    def initialize(config)
      @config = config
    end

    def valid_get_treatment_parameters(method, key, split_name, matching_key, bucketing_key, attributes)
      valid_key?(method, key) &&
        valid_split_name?(method, split_name) &&
        valid_matching_key?(method, matching_key) &&
        valid_bucketing_key?(method, key, bucketing_key) &&
        valid_attributes?(method, attributes)
    end

    def valid_get_treatments_parameters(method, key, split_names, matching_key, bucketing_key, attributes)
      valid_key?(method, key) &&
        valid_split_names?(method, split_names)
        valid_matching_key?(method, matching_key) &&
        valid_bucketing_key?(method, key, bucketing_key) &&
        valid_attributes?(method, attributes)
    end

    def valid_track_parameters(key, traffic_type_name, event_type, value, properties)
      valid_track_key?(key) &&
        valid_traffic_type_name?(traffic_type_name) &&
        valid_event_type?(event_type) &&
        valid_value?(value) &&
        valid_properties?(properties)
    end

    def valid_split_parameters(split_name)
      valid_split_name?(:split, split_name)
    end

    def valid_matcher_arguments(args)
      return false if !args.key?(:attributes) && !args.key?(:value)
      return false if args.key?(:value) && args[:value].nil?
      return false if args.key?(:attributes) && args[:attributes].nil?
      true
    end

    def valid_flag_sets(method, flag_sets)
      if flag_sets.nil? || !flag_sets.is_a?(Array)
        @config.logger.error("#{method}: FlagSets must be a non-empty list.")
        return []
      end
      if flag_sets.empty?
        @config.logger.error("#{method}: FlagSets must be a non-empty list.")
        return []
      end
      without_nil = Array.new
      flag_sets.each { |flag_set|
        without_nil.push(flag_set) if !flag_set.nil?
        log_nil("flag set", method) if flag_set.nil?
      }
      if without_nil.length() == 0
        log_invalid_flag_set_type(method)
        return []
      end
      valid_flag_sets = SortedSet[]
      without_nil.compact.uniq.select do |flag_set|
        if flag_set.nil? || !flag_set.is_a?(String)
          log_invalid_flag_set_type(method)
        elsif flag_set.is_a?(String) && flag_set.empty?
          log_invalid_flag_set_type(method)
        elsif !flag_set.empty? && string_match?(flag_set.strip.downcase, method)
          valid_flag_sets.add(flag_set.strip.downcase)
        else
          log_invalid_flag_set_type(method)
        end
      end
      !valid_flag_sets.empty? ? valid_flag_sets.to_a :  []
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

    def string_match?(value, method)
      if Flagset_regex.match(value) == nil
        log_invalid_match(value, method)
        false
      else
        true
      end
    end

    def log_invalid_match(key, method)
      @config.logger.error("#{method}: you passed #{key}, flag set must adhere to the regular expression #{Flagset_regex}. " +
      "This means flag set must be alphanumeric, cannot be more than 50 characters long, and can only include a dash, underscore, " +
      "period, or colon as separators of alphanumeric characters.")
    end

    def log_nil(key, method)
      msg_text = String.new("#{method}: you passed a nil #{key}, #{key} must be a non-empty String")
      msg_text << " or a Symbol" if !key.equal?("flag set")
      @config.logger.error(msg_text)
    end

    def log_empty_string(key, method)
      @config.logger.error("#{method}: you passed an empty #{key}, #{key} must be a non-empty String or a Symbol")
    end

    def log_invalid_type(key, method)
      @config.logger.error("#{method}: you passed an invalid #{key} type, #{key} must be a non-empty String or a Symbol")
    end

    def log_invalid_flag_set_type(method)
      @config.logger.warn("#{method}: you passed an invalid flag set type, flag set must be a non-empty String")
    end

    def log_convert_numeric(key, method, value)
      @config.logger.warn("#{method}: #{key} \"#{value}\" is not of type String, converting")
    end

    def log_key_too_long(key, method)
      @config.logger.error("#{method}: #{key} is too long - must be #{@config.max_key_size} characters or less")
    end

    def valid_split_name?(method, split_name)
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

    def valid_key?(method, key)
      if key.nil?
        log_nil(:key, method)
        return false
      end

      true
    end

    def valid_matching_key?(method, matching_key)
      if matching_key.nil?
        log_nil(:matching_key, method)
        return false
      end

      unless number_or_string?(matching_key)
        log_invalid_type(:matching_key, method)
        return false
      end

      if empty_string?(matching_key)
        log_empty_string(:matching_key, method)
        return false
      end

      log_convert_numeric(:matching_key, method, matching_key) if matching_key.is_a? Numeric

      if matching_key.size > @config.max_key_size
        log_key_too_long(:matching_key, method)
        return false
      end

      true
    end

    def valid_bucketing_key?(method, key, bucketing_key)
      if key.is_a? Hash
        if bucketing_key.nil?
          log_nil(:bucketing_key, method)
          return false
        end

        unless number_or_string?(bucketing_key)
          log_invalid_type(:bucketing_key, method)
          return false
        end

        if empty_string?(bucketing_key)
          log_empty_string(:bucketing_key, method)
          return false
        end

        log_convert_numeric(:bucketing_key, method, bucketing_key) if bucketing_key.is_a? Numeric

        if bucketing_key.size > @config.max_key_size
          log_key_too_long(:bucketing_key, method)
          return false
        end
      end

      true
    end

    def valid_split_names?(method, split_names)
      unless !split_names.nil? && split_names.is_a?(Array)
        @config.logger.error("#{method}: feature_flag_names must be a non-empty Array")
        return false
      end

      true
    end

    def valid_attributes?(method, attributes)
      unless attributes.nil? || attributes.is_a?(Hash)
        @config.logger.error("#{method}: attributes must be of type Hash")
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

      if key.size > @config.max_key_size
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
        @config.logger.error("track: you passed '#{event_type}', " \
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
        @config.logger.warn('track: traffic_type_name should be all lowercase - ' \
          'converting string to lowercase')
      end

      true
    end

    def valid_value?(value)
      unless (value.is_a?(Numeric) && !value.to_f.nan?) || value.nil?
        @config.logger.error('track: value must be Numeric')
        return false
      end

      true
    end

    def valid_properties?(properties)
      unless properties.is_a?(Hash) || properties.nil?
        @config.logger.error('track: properties must be a Hash')
        return false
      end

      true
    end
  end
end
