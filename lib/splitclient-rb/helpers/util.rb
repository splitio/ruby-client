# frozen_string_literal: true

module SplitIoClient
  module Helpers
    class Util
      def self.segment_names_by_object(object, matcher_type)
        object[:conditions].each_with_object(Set.new) do |condition, names|
          condition[:matcherGroup][:matchers].each do |matcher|
            next if matcher[:userDefinedSegmentMatcherData].nil? || matcher[:matcherType] != matcher_type

            names << matcher[:userDefinedSegmentMatcherData][:segmentName]
          end
        end
      end

      def self.segment_names_in_rb_segment(object, matcher_type)
        names = Set.new 
        names.merge segment_names_by_object(object, matcher_type)
        object[:excluded][:segments].each do |segment|
            if segment[:type] == 'standard'
              names.add(segment[:name])
            end
        end
        names
      end
    end
  end
end
