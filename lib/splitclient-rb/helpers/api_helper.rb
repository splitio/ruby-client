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
    end
  end
end
