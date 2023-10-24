# frozen_string_literal: true

require 'set'

module SplitIoClient
  module Cache
    module Filter
      class FlagSetsFilter
        def initialize(flag_sets = [])
          @flag_sets = Set.new(flag_sets)
          @should_filter = @flag_sets.any?
        end

        def flag_set_exist?(flag_set)
          return true unless @should_filter

          if not flag_set.is_a?(String) or flag_set.empty?
            return false
          end

          @flag_sets.intersection([flag_set]).any?
        end

        def intersect?(flag_sets)
          return true unless @should_filter

          if not flag_sets.is_a?(Array) or flag_sets.empty?
            return false
          end

          @flag_sets.intersection(Set.new(flag_sets)).any?
        end
      end
    end
  end
end
