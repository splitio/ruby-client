# frozen_string_literal: true

module SplitIoClient
  module Api
    # Retrieves split definitions from the Split Backend
    class SplitsJSONLocalhost
      def initialize(split_repository, config)
        @config = config
        @split_file = config.split_file
        @splits_sha = Digest::SHA256.hexdigest('')
        @split_repository = split_repository
      end

      def since(since = -1, fetch_options = {})
        begin
          fetched = read_feature_flags_from_json_file
          fetched_sha = Digest::SHA256.hexdigest(fetched.to_s)
          return {} if fetched_sha == @splits_sha
          @splits_sha = fetched_sha

          return {} if @split_repository.get_change_number > fetched[:till] && fetched[:till] != -1
#          result = splits_with_segment_names(fetched)
          unless fetched[:splits].empty?
            @config.logger.debug("#{fetched[:splits].length} feature flags retrieved. till=#{fetched[:till]}")
          end

          fetched
        rescue StandardError => e
          @config.logger.error("Exception synching feature flags: #{e.message}")
        end
      end

      private

      def splits_with_segment_names(parsed_splits)
        parsed_splits[:segment_names] =
          parsed_splits.each_with_object(Set.new) do |split, splits|
            splits << Helpers::Util.segment_names_by_feature_flag(split)
          end.flatten

        parsed_splits
      end

      def read_feature_flags_from_json_file
        begin
          @config.logger.debug("Syncing feature flags from file system.")
          raise "Feature flags file \'#{@split_file}\' does not exist" if !File.exists?(@split_file)

          parsed = JSON.parse(File.read(@split_file), symbolize_names: true)
          santitized = sanitize_feature_flag(parsed)
          return santitized
        rescue StandardError => e
          @config.logger.error("Exception caught: #{e.message}")
          raise "Error parsing splits file \'#{@split_file}\', Make sure it's readable."
        end
      end

      def sanitize_feature_flag(parsed)
        parsed = sanitize_json_elements(parsed)
        parsed[:splits] = sanitize_feature_flag_elements(parsed[:splits])
        parsed
      end

      def sanitize_json_elements(parsed)
        if !parsed.key?(:splits) || parsed[:splits].nil?
          parsed[:splits] = []
        end
        if !parsed.key?(:till) || parsed[:till].nil? || parsed[:till] < -1
          parsed[:till] = -1
        end
        if !parsed.key?(:since) || parsed[:since].nil? || parsed[:since] < -1 || parsed[:since] > parsed[:till]
            parsed[:since] = parsed[:till]
        end
        parsed
      end

      def sanitize_feature_flag_elements(parsed_feature_flags)
        sanitized_feature_flags = []
        parsed_feature_flags.each do |feature_flag|
          if !feature_flag.key?(:name) || feature_flag[:name].empty?
            @config.logger.warn("A feature flag in json file does not have (Name) or property is empty, skipping.")
            next
          end
          elements = [[:trafficTypeName, 'user', nil, nil, nil, nil],
            [:trafficAllocation, 100, 0, 100,  nil, nil],
            [:trafficAllocationSeed, Time.now.to_i, nil, nil, nil, [0]],
            [:seed, Time.now.to_i, nil, nil, nil, [0]],
            [:status, 'ACTIVE', nil, nil, ['ACTIVE','KILLED','ARCHIVED'], nil],
            [:killed, false, nil, nil, nil, nil],
            [:defaultTreatment, 'control', nil, nil, nil, ['', ' ']],
            [:changeNumber, 0, 0, nil, nil, nil],
            [:algo, 2, 2, 2, nil, nil]
          ]
          elements.each { |element|
            feature_flag = Helpers::ApiHelper.sanitize_object_element(@config.logger, feature_flag, 'split', element[0], element[1], lower_value=element[2], upper_value=element[3], in_list=element[4], not_in_list=element[5])
          }
          feature_flag = sanitize_condition(feature_flag)

          feature_flag[:sets] = [] if !feature_flag.key?(:sets)
          feature_flag[:sets] = @config.split_validator.valid_flag_sets('Localhost Validator', feature_flag[:sets])

          sanitized_feature_flags.append(feature_flag)
        end
        sanitized_feature_flags
      end

      def sanitize_condition(feature_flag)
        found_all_keys_matcher = false
        feature_flag[:conditions] = [] if !feature_flag.key?(:conditions)

        if feature_flag[:conditions].length() > 0
          last_condition = feature_flag[:conditions][-1]
          if last_condition.key?(:conditionType)
            if last_condition[:conditionType] == 'ROLLOUT'
              if last_condition.key?(:matcherGroup)
                if last_condition[:matcherGroup].key?(:matchers)
                  last_condition[:matcherGroup][:matchers].each { |matcher|
                    if matcher[:matcherType] == 'ALL_KEYS'
                      found_all_keys_matcher = true
                      break
                    end
                  }
                end
              end
            end
          end
        end
        if !found_all_keys_matcher
          @config.logger.debug("Missing default rule condition for feature flag: \'#{feature_flag[:name]}\', adding default rule with 100%% off treatment")
          feature_flag[:conditions].append(
          {
            :conditionType => "ROLLOUT",
            :matcherGroup => {
              :combiner => "AND",
              :matchers => [{
                :keySelector => { :trafficType => "user", :attribute => nil },
                :matcherType => "ALL_KEYS",
                :negate => false,
                :userDefinedSegmentMatcherData => nil,
                :whitelistMatcherData => nil,
                :unaryNumericMatcherData => nil,
                :betweenMatcherData => nil,
                :booleanMatcherData => nil,
                :dependencyMatcherData => nil,
                :stringMatcherData => nil
              }]
            },
            :partitions => [
                { :treatment => "on", :size => 0 },
                { :treatment => "off", :size => 100 }
            ],
            :label => "default rule"
          })
        end

        feature_flag
      end
    end
  end
end
