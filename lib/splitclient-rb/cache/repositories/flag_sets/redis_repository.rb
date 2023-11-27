require 'concurrent'

module SplitIoClient
  module Cache
    module Repositories
      class RedisFlagSetsRepository < Repository

        def initialize(config)
          super(config)
          @adapter = SplitIoClient::Cache::Adapters::CacheAdapter.new(@config)
        end

        def flag_set_exist?(flag_set)
          @adapter.exists?(namespace_key(".flagSet.#{flag_set}"))
        end

        def get_flag_set(flag_set)
          @adapter.get_set(namespace_key(".flagSet.#{flag_set}"))
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
