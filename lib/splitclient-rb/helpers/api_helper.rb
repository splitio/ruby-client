# frozen_string_literal: true

module SplitIoClient
  module Helpers
    class ApiHelper
      def self.sanitize_object_element(logger, object, object_name, element_name, default_value, lower_value=nil, upper_value=nil, in_list=nil, not_in_list=nil)
        if !object.key?(element_name) || object[element_name].nil?
          object[element_name] = default_value
          logger.debug("Sanitized element \'#{element_name}\' to \'#{default_value}\' in #{object_name}: #{object['name']}.")
        end
        if !lower_value.nil? && !upper_value.nil?
          if object[element_name] < lower_value or object[element_name] > upper_value
            object[element_name] = default_value
            logger.debug("Sanitized element \'#{element_name}\' to \'#{default_value}\' in #{object_name}: #{object['name']}.")
          end
        elsif !lower_value.nil?
          if object[element_name] < lower_value
            object[element_name] = default_value
            logger.debug("Sanitized element \'#{element_name}\' to \'#{default_value}\' in #{object_name}: #{object['name']}.")
          end
        elsif !upper_value.nil?
          if object[element_name] > upper_value
            object[element_name] = default_value
            logger.debug("Sanitized element \'#{element_name}\' to \'#{default_value}\' in #{object_name}: #{object['name']}.")
          end
        end
        if !in_list.nil?
          if !in_list.include?(object[element_name])
            object[element_name] = default_value
            logger.debug("Sanitized element \'#{element_name}\' to \'#{default_value}\' in #{object_name}: #{object['name']}.")
          end
        end
        if !not_in_list.nil?
          if not_in_list.include?(object[element_name])
            object[element_name] = default_value
            logger.debug("Sanitized element \'#{element_name}\' to \'#{default_value}\' in #{object_name}: #{object['name']}.")
          end
        end
        object
      end

      def self.sanitize_feature_flag(config, parsed)
        parsed = sanitize_json_elements(parsed)
        parsed[:splits] = sanitize_feature_flag_elements(config, parsed[:splits])
        parsed
      end

      def self.sanitize_json_elements(parsed)
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

      def self.sanitize_feature_flag_elements(config, parsed_feature_flags)
        sanitized_feature_flags = []
        parsed_feature_flags.each do |feature_flag|
          if !feature_flag.key?(:name) || feature_flag[:name].empty?
            config.logger.warn("A feature flag in json file does not have (Name) or property is empty, skipping.")
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
            feature_flag = sanitize_object_element(config.logger, feature_flag, 'split', element[0], element[1], lower_value=element[2], upper_value=element[3], in_list=element[4], not_in_list=element[5])
          }
          feature_flag = sanitize_condition(config.logger, feature_flag)

          feature_flag[:sets] = [] if !feature_flag.key?(:sets)
          feature_flag[:sets] = config.split_validator.valid_flag_sets('Localhost Validator', feature_flag[:sets])

          sanitized_feature_flags.append(feature_flag)
        end
        sanitized_feature_flags
      end

      def self.sanitize_condition(logger, feature_flag)
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
          logger.debug("Missing default rule condition for feature flag: \'#{feature_flag[:name]}\', adding default rule with 100%% off treatment")
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

      def self.sanitize_segment(logger, parsed)
        if !parsed.key?(:name) || parsed[:name].nil?
          logger.warn("Segment does not have [name] element, skipping")
          raise "Segment does not have [name] element"
        end
        if parsed[:name].strip.empty?
          logger.warn("Segment [name] element is blank, skipping")
          raise "Segment [name] element is blank"
        end

        [[:till, -1, -1, nil, nil, [0]],
                        [:added, [], nil, nil, nil, nil],
                        [:removed, [], nil, nil, nil, nil]
        ].each { |element|
            parsed = sanitize_object_element(logger, parsed, 'segment', element[0], element[1], lower_value=element[2], upper_value=element[3], in_list=nil, not_in_list=element[5])
        }
        parsed = sanitize_object_element(logger, parsed, 'segment', :since, parsed[:till], -1, parsed[:till], nil, [0])
      end
    end
  end
end
