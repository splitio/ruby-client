require 'concurrent'

module SplitIoClient
  module Cache
    module Repositories
      class MemoryFlagSetsRepository
        def initialize(flag_sets = [])
          @sets_feature_flag_map = {}
          flag_sets.each{ |flag_set| @sets_feature_flag_map[flag_set] = Set[] }
        end

        def flag_set_exist?(flag_set)
          @sets_feature_flag_map.key?(flag_set)
        end

        def get_flag_sets(flag_sets)
          to_return = Array.new
          flag_sets.each { |flag_set| to_return.concat(@sets_feature_flag_map[flag_set].to_a)}
          to_return.uniq
        end

        def add_flag_set(flag_set)
          @sets_feature_flag_map[flag_set] = Set[] if !flag_set_exist?(flag_set)
        end

        def remove_flag_set(flag_set)
          @sets_feature_flag_map.delete(flag_set) if flag_set_exist?(flag_set)
        end

        def add_feature_flag_to_flag_set(flag_set, feature_flag)
          @sets_feature_flag_map[flag_set].add(feature_flag) if flag_set_exist?(flag_set)
        end

        def remove_feature_flag_from_flag_set(flag_set, feature_flag)
          @sets_feature_flag_map[flag_set].delete(feature_flag) if flag_set_exist?(flag_set)
        end
      end
    end
  end
end
