# frozen_string_literal: true

module SplitIoClient
  module Helpers
    class Util
      def self.segment_names_by_object(object, matcher_type)
        object[:conditions].each_with_object(Set.new) do |condition, names|
          condition[:matcherGroup][:matchers].each do |matcher|
            next if matcher[:userDefinedSegmentMatcherData].nil? or matcher[:matcherType] != matcher_type
            names << matcher[:userDefinedSegmentMatcherData][:segmentName]
          end
        end
      end
    end
  end
end
