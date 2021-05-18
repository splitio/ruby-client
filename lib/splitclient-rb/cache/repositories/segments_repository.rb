module SplitIoClient
  module Cache
    module Repositories
      class SegmentsRepository < Repository
        KEYS_SLICE = 3000

        attr_reader :adapter

        def initialize(config)
          super(config)
          @adapter = case @config.cache_adapter.class.to_s
          when 'SplitIoClient::Cache::Adapters::RedisAdapter'
            SplitIoClient::Cache::Adapters::CacheAdapter.new(@config)
          else
            @config.cache_adapter
          end
          @adapter.set_bool(namespace_key('.ready'), false) unless @config.mode.equal?(:consumer)
        end

        # Receives segment data, adds and removes segements from the store
        def add_to_segment(segment)
          name = segment[:name]

          @adapter.initialize_set(segment_data(name)) unless @adapter.exists?(segment_data(name))

          add_keys(name, segment[:added])
          remove_keys(name, segment[:removed])
        end

        def get_segment_keys(name)
          @adapter.get_set(segment_data(name))
        end

        def in_segment?(name, key)
          @adapter.in_set?(segment_data(name), key)
        end

        def used_segment_names
          @adapter.get_set(namespace_key('.segments.registered'))
        end

        def set_change_number(name, last_change)
          @adapter.set_string(namespace_key(".segment.#{name}.till"), last_change)
        end

        def get_change_number(name)
          @adapter.string(namespace_key(".segment.#{name}.till")) || -1
        end

        def ready?
          @adapter.string(namespace_key('.segments.ready')).to_i != -1
        end

        def not_ready!
          @adapter.set_string(namespace_key('.segments.ready'), -1)
        end

        def ready!
          @adapter.set_string(namespace_key('.segments.ready'), Time.now.utc.to_i)
        end

        def clear
          @adapter.clear(namespace_key)
        end

        def segments_count
          used_segment_names.length
        end

        def segment_keys_count
          names = used_segment_names

          keys = 0

          names.each do |name|
            segment_keys = get_segment_keys(name)            
            keys += segment_keys.length
          end
          
          keys
        rescue StandardError => error
          @config.log_found_exception(__method__.to_s, error)
          0
        end

        private

        def segment_data(name)
          namespace_key(".segment.#{name}")
        end

        def add_keys(name, keys)
          keys.each_slice(KEYS_SLICE) do |keys_slice|
            @adapter.add_to_set(segment_data(name), keys_slice)
          end
        end

        def remove_keys(name, keys)
          keys.each_slice(KEYS_SLICE) do |keys_slice|
            @adapter.delete_from_set(segment_data(name), keys_slice)
          end
        end
      end
    end
  end
end
