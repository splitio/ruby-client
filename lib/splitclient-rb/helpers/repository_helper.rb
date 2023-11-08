# frozen_string_literal: true

module SplitIoClient
  module Helpers
    class RepositoryHelper
      def self.update_feature_flag_repository(feature_flag_repository, feature_flags, change_number, config)
        to_add = []
        to_delete = []
        for feature_flag in feature_flags
          if Engine::Models::Split.archived?(feature_flag) || !feature_flag_repository.flag_set_filter.intersect?(feature_flag[:sets])
            config.logger.debug("removing feature flag from store(#{feature_flag})") if config.debug_enabled
            to_delete.push(feature_flag)
            next
          end

          config.logger.debug("storing feature flag (#{feature_flag[:name]})") if config.debug_enabled
          to_add.push(feature_flag)
        end
        feature_flag_repository.update(to_add, to_delete, change_number)
      end
    end
  end
end
