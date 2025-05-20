# frozen_string_literal: true

module SplitIoClient
  module Helpers
    class RepositoryHelper
      def self.update_feature_flag_repository(feature_flag_repository, feature_flags, change_number, config, clear_storage)
        to_add = []
        to_delete = []
        feature_flags.each do |feature_flag|
          if Engine::Models::Split.archived?(feature_flag) || !feature_flag_repository.flag_set_filter.intersect?(feature_flag[:sets])
            config.logger.debug("removing feature flag from store(#{feature_flag})") if config.debug_enabled
            to_delete.push(feature_flag)
            next
          end

          feature_flag = check_impressions_disabled(feature_flag, config)

          config.logger.debug("storing feature flag (#{feature_flag[:name]})") if config.debug_enabled
          to_add.push(feature_flag)
        end
        feature_flag_repository.clear if clear_storage
        feature_flag_repository.update(to_add, to_delete, change_number)
      end

      def self.check_impressions_disabled(feature_flag, config)
        unless feature_flag.key?(:impressionsDisabled)
          feature_flag[:impressionsDisabled] = false
          if config.debug_enabled
            config.logger.debug("feature flag (#{feature_flag[:name]}) does not have impressionsDisabled field, setting it to false")
          end
        end
        feature_flag
      end

      def self.update_rule_based_segment_repository(rule_based_segment_repository, rule_based_segments, change_number, config)
        to_add = []
        to_delete = []
        rule_based_segments.each do |rule_based_segment|
          if Engine::Models::Split.archived?(rule_based_segment)
            config.logger.debug("removing rule based segment from store(#{rule_based_segment})") if config.debug_enabled
            to_delete.push(rule_based_segment)
            next
          end

          config.logger.debug("storing rule based segment (#{rule_based_segment[:name]})") if config.debug_enabled
          to_add.push(rule_based_segment)
        end

        rule_based_segment_repository.update(to_add, to_delete, change_number)
      end
    end
  end
end
