require 'concurrent'

module SplitIoClient
  module Cache
    module Repositories
      class RedisFlagSetsRepository < Repository

        def initialize(config)
          super(config)
          @adapter = SplitIoClient::Cache::Adapters::RedisAdapter.new(@config.redis_url)
        end

        def flag_set_exist?(flag_set)
          @adapter.exists?(namespace_key(".flagSet.#{flag_set}"))
        end

        def get_flag_sets(flag_sets)
          result = @adapter.redis.pipelined do |pipeline|
            flag_sets.each do |flag_set|
               pipeline.smembers(namespace_key(".flagSet.#{flag_set}"))
            end
          end
          to_return = Array.new
          result.each do |flag_set|
            flag_set.each { |feature_flag_name| to_return.push(feature_flag_name.to_s)}
          end
          to_return.uniq
        end

        def add_flag_set(flag_set)
          # not implemented
        end

        def remove_flag_set(flag_set)
          # not implemented
        end

        def add_feature_flag_to_flag_set(flag_set, feature_flag)
          # not implemented
        end

        def remove_feature_flag_from_flag_set(flag_set, feature_flag)
          # not implemented
        end

      end
    end
  end
end
