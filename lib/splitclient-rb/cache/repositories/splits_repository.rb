require 'concurrent'

module SplitIoClient
  module Cache
    module Repositories
      class SplitsRepository < Repository
        attr_reader :adapter

        def initialize(config)
          super(config)
          @tt_cache = {}
          @adapter = case @config.cache_adapter.class.to_s
          when 'SplitIoClient::Cache::Adapters::RedisAdapter'
            SplitIoClient::Cache::Adapters::CacheAdapter.new(@config)
          else
            @config.cache_adapter
          end
          unless @config.mode.equal?(:consumer)
            @adapter.set_string(namespace_key('.splits.till'), '-1')
            @adapter.initialize_map(namespace_key('.segments.registered'))
          end
        end

        def add_split(split)
          return unless split[:name]
          existing_split = get_split(split[:name])

          if(!existing_split)
            increase_tt_name_count(split[:trafficTypeName])
          elsif(existing_split[:trafficTypeName] != split[:trafficTypeName])
            increase_tt_name_count(split[:trafficTypeName])
            decrease_tt_name_count(existing_split[:trafficTypeName])
          end

          @adapter.set_string(namespace_key(".split.#{split[:name]}"), split.to_json)
        end

        def remove_split(split)
          tt_name = split[:trafficTypeName]

          decrease_tt_name_count(split[:trafficTypeName])

          @adapter.delete(namespace_key(".split.#{split[:name]}"))
        end

        def get_splits(names, symbolize_names = true)
          splits = {}
          split_names = names.map { |name| namespace_key(".split.#{name}") }
          splits.merge!(
            @adapter
              .multiple_strings(split_names)
              .map { |name, data| [name.gsub(namespace_key('.split.'), ''), data] }.to_h
          )

          splits.map do |name, data|
            parsed_data = data ? JSON.parse(data, symbolize_names: true) : nil
            split_name = symbolize_names ? name.to_sym : name
            [split_name, parsed_data]
          end.to_h
        end

        def get_split(name)
          split = @adapter.string(namespace_key(".split.#{name}"))

          JSON.parse(split, symbolize_names: true) if split
        end

        def splits
          get_splits(split_names, false)
        end

        def traffic_type_exists(tt_name)
          case @adapter
          when SplitIoClient::Cache::Adapters::CacheAdapter
            tt_count = @adapter.string(namespace_key(".trafficType.#{tt_name}"))
            begin
              !tt_count.nil? && Integer(tt_count, 10) > 0
            rescue StandardError => e
              @config.logger.error("Error while parsing Traffic Type count: #{e.message}")
              false
            end
          else
            @tt_cache.key?(tt_name) && @tt_cache[tt_name] > 0
          end
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
          @tt_cache.clear

          @adapter.clear(namespace_key)
        end

        private

        def increase_tt_name_count(tt_name)
          return unless tt_name

          @tt_cache[tt_name] = 0 unless @tt_cache[tt_name]
          @tt_cache[tt_name] += 1
        end

        def decrease_tt_name_count(tt_name)
          return unless tt_name

          @tt_cache[tt_name] -= 1 if @tt_cache[tt_name]
          @tt_cache.delete(tt_name) if @tt_cache[tt_name] == 0
        end
      end
    end
  end
end
