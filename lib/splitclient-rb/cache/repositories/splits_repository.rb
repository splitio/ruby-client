require 'concurrent'

module SplitIoClient
  module Cache
    module Repositories
      class SplitsRepository < Repository
        attr_reader :adapter

        def initialize(adapter)
          @adapter = case adapter.class.to_s
          when 'SplitIoClient::Cache::Adapters::RedisAdapter'
            SplitIoClient::Cache::Adapters::CacheAdapter.new(adapter)
          else
            adapter
          end
          unless SplitIoClient.configuration.mode == :consumer
            @adapter.set_string(namespace_key('.splits.till'), '-1')
            @adapter.initialize_map(namespace_key('.segments.registered'))
          end
        end

        def add_split(split)
          return unless split[:name]

          @adapter.set_string(namespace_key(".split.#{split[:name]}"), split.to_json)
        end

        def remove_split(name)
          @adapter.delete(namespace_key(".split.#{name}"))
        end

        def get_splits(names)
          splits = {}
          split_names = names.map { |name| namespace_key(".split.#{name}") }
          splits.merge!(
            @adapter
              .multiple_strings(split_names)
              .map { |name, data| [name.gsub(namespace_key('.split.'), ''), data] }.to_h
          )

          splits.map do |name, data|
            parsed_data = data ? JSON.parse(data, symbolize_names: true) : nil
            [name.to_sym, parsed_data]
          end.to_h
        end

        def get_split(name)
          split = @adapter.string(namespace_key(".split.#{name}"))

          JSON.parse(split, symbolize_names: true) if split
        end

        def splits
          splits_hash = {}

          split_names.each do |name|
            splits_hash[name] = get_split(name)
          end

          splits_hash
        end

        # Return an array of Split Names excluding control keys like splits.till
        def split_names
          @adapter.find_strings_by_prefix(namespace_key('.split.'))
            .map { |split| split.gsub(namespace_key('.split.'), '') }
        end

        def set_change_number(since)
          @adapter.set_string(namespace_key('.splits.till'), since)
        end

        def get_change_number
          @adapter.string(namespace_key('.splits.till'))
        end

        def set_segment_names(names)
          return if names.nil? || names.empty?

          names.each do |name|
            @adapter.add_to_set(namespace_key('.segments.registered'), name)
          end
        end

        def exists?(name)
          @adapter.exists?(namespace_key(".split.#{name}"))
        end

        def ready?
          @adapter.string(namespace_key('.splits.ready')).to_i != -1
        end

        def not_ready!
          @adapter.set_string(namespace_key('.splits.ready'), -1)
        end

        def ready!
          @adapter.set_string(namespace_key('.splits.ready'), Time.now.utc.to_i)
        end

        def clear
          @adapter.clear(namespace_key)
        end
      end
    end
  end
end
