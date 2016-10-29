require 'concurrent'

module SplitIoClient
  module Cache
    module Repositories
      class SplitsRepository < Repository
        def initialize(adapter)
          @adapter = adapter

          @adapter.set_string(namespace_key('split.till'), '-1')
          @adapter.initialize_map(namespace_key('segments.registered'))
        end

        def add_split(split)
          @adapter.set_string(namespace_key("split.#{split[:name]}"), split.to_json)
        end

        def remove_split(name)
          @adapter.delete(namespace_key("split.#{name}"))
        end

        def get_split(name, prefixed = false)
          split = prefixed ? @adapter.string(name) : @adapter.string(namespace_key("split.#{name}"))

          JSON.parse(split, symbolize_names: true)
        end

        def splits
          splits_hash = {}
          splits = []
          split_names = @adapter.find_strings_by_prefix(namespace_key('split'))

          split_names.each do |name|
            next if name == namespace_key('split.till')

            splits << get_split(name, true)
          end

          splits.each do |split|
            splits_hash[split[:name]] = split
          end

          splits_hash
        end

        # Return an array of Split Names excluding control keys like split.till
        def splitNames
          names = []
          split_names = @adapter.find_strings_by_prefix(namespace_key('split'))

          split_names.each do |name|
            next if name == namespace_key('split.till')
            names << name.dup.sub!(namespace_key('split.'), "")
          end
          names
        end

        def set_change_number(since)
          @adapter.set_string(namespace_key('split.till'), since)
        end

        def get_change_number
          @adapter.string(namespace_key('split.till'))
        end

        def set_segment_names(names)
          return if names.nil? || names.empty?

          names.each do |name|
            @adapter.add_to_set(namespace_key('segments.registered'), name)
          end
        end
      end
    end
  end
end
