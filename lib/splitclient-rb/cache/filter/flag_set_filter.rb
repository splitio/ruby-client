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
          if not @should_filter
            return true
          end
          if not flag_set.respond_to?(:lstrip!) or flag_set.empty?
            return false
          end

          @flag_sets.intersection([flag_set]).any?
        end

        def intersect?(flag_sets)
          if not @should_filter
            return true
          end
          if not flag_sets.respond_to?(:each) or flag_sets.empty?
            return false
          end

          @flag_sets.intersection(Set.new(flag_sets)).any?
        end
      end
    end
  end
end
