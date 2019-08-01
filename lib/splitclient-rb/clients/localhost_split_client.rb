module SplitIoClient
  class LocalhostSplitClient
    include SplitIoClient::LocalhostUtils

    #
    # variables to if the sdk is being used in localhost mode and store the list of features
    attr_reader :localhost_mode
    attr_reader :localhost_mode_features

    #
    # Creates a new split client instance that reads from the given splits file
    #
    # @param splits_file [File] file that contains some splits
    #
    # @return [LocalhostSplitIoClient] split.io localhost client instance
    def initialize(splits_file, config, reload_rate = nil)
      @localhost_mode = true
      @localhost_mode_features = []
      load_localhost_mode_features(splits_file, reload_rate)
      @config = config
    end

    #
    # method that returns the sdk gem version
    #
    # @return [string] version value for this sdk
    def self.sdk_version
      'ruby-'+SplitIoClient::VERSION
    end

    #
    # obtains the treatments and configs for a given set of features
    #
    # @param key [string] evaluation key, only used with yaml split files
    # @param split_names [array] name of the features being validated
    # @param attributes [hash] kept for consistency with actual SDK client. Omitted in calls
    #
    # @return [hash] map of treatments (split_name, treatment)
    def get_treatments_with_config(key, split_names, attributes = nil)
      get_localhost_treatments(key, split_names, attributes, 'get_treatments_with_config')
    end

    #
    # obtains the treatments for a given set of features
    #
    # @param key [string] evaluation key, only used with yaml split files
    # @param split_names [array] name of the features being validated
    # @param attributes [hash] kept for consistency with actual SDK client. Omitted in calls
    #
    # @return [hash] map of treatments (split_name, treatment_name)
    def get_treatments(key, split_names, attributes = nil)
      treatments = get_localhost_treatments(key, split_names, attributes)
      return treatments if treatments.nil?
      keys = treatments.keys
      treats = treatments.map { |_,t| t[:treatment]  }
      Hash[keys.zip(treats)]
    end

    #
    # obtains the treatment for a given feature
    #
    # @param key [string] evaluation key, only used with yaml split files
    # @param split_name [string] name of the feature that is being validated
    # @param attributes [hash] kept for consistency with actual SDK client. Omitted in calls
    #
    # @return [string] corresponding treatment
    def get_treatment(key, split_name, attributes = nil)
      get_localhost_treatment(key, split_name, attributes)[:treatment]
    end

    #
    # obtains the treatment and config for a given feature
    #
    # @param key [string] evaluation key, only used with yaml split files
    # @param split_name [string] name of the feature that is being validated
    # @param attributes [hash] kept for consistency with actual SDK client. Omitted in calls
    #
    # @return [hash]  corresponding treatment and config
    def get_treatment_with_config(key, split_name, attributes = nil)
      get_localhost_treatment(key, split_name, attributes, 'get_treatment_with_config')
    end

    def track
    end

    private

    #
    # method to check if the sdk is running in localhost mode based on api key
    #
    # @return [boolean] True if is in localhost mode, false otherwise
    def is_localhost_mode?
      true
    end

    # @param key [string] evaluation key, only used with yaml split files
    # @param split_name [string] name of the feature that is being validated
    #
    # @return [Hash] corresponding treatment and config, control otherwise
    def get_localhost_treatment(key, split_name, attributes, calling_method = 'get_treatment')
      control_treatment = { label: Engine::Models::Label::EXCEPTION, treatment: SplitIoClient::Engine::Models::Treatment::CONTROL, config: nil }
      parsed_control_treatment = parsed_treatment(control_treatment)

      bucketing_key, matching_key = keys_from_key(key)
      return parsed_control_treatment unless @config.split_validator.valid_get_treatment_parameters(calling_method, key, split_name, matching_key, bucketing_key, attributes)

      sanitized_split_name = split_name.to_s.strip

      if split_name.to_s != sanitized_split_name
        @config.logger.warn("get_treatment: split_name #{split_name} has extra whitespace, trimming")
        split_name = sanitized_split_name
      end

      treatment = @localhost_mode_features.select { |h| h[:feature] == split_name && has_key(h[:keys], key) }.last

      if treatment.nil?
        treatment = @localhost_mode_features.select { |h| h[:feature] == split_name && h[:keys] == nil }.last
      end

      if treatment && treatment[:treatment]
        {
          treatment: treatment[:treatment],
          config: treatment[:config]
        }
      else
        parsed_control_treatment
      end
    end

    def get_localhost_treatments(key, split_names, attributes = nil, calling_method = 'get_treatments')
      return nil unless @config.split_validator.valid_get_treatments_parameters(calling_method, split_names)

      sanitized_split_names = sanitize_split_names(calling_method, split_names)

      if sanitized_split_names.empty?
        @config.logger.error("#{calling_method}: split_names must be a non-empty Array")
        return {}
      end

      split_names.each_with_object({}) do |split_name, memo|
        memo.merge!(split_name => get_treatment_with_config(key, split_name, attributes))
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

    def parsed_treatment(treatment_data)
      {
        treatment: treatment_data[:treatment],
        config: treatment_data[:config]
      }
    end

    def has_key(keys, key)
      case keys
        when Array then keys.include? key
        when String then keys == key
      else
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
  end
end
