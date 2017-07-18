require 'splitclient-rb/version'

require 'splitclient-rb/exceptions/sdk_blocker_timeout_expired_exception'
require 'splitclient-rb/cache/adapters/memory_adapters/map_adapter'
require 'splitclient-rb/cache/adapters/memory_adapters/queue_adapter'
require 'splitclient-rb/cache/adapters/memory_adapter'
require 'splitclient-rb/cache/adapters/redis_adapter'
require 'splitclient-rb/cache/repositories/repository'
require 'splitclient-rb/cache/repositories/segments_repository'
require 'splitclient-rb/cache/repositories/splits_repository'
require 'splitclient-rb/cache/repositories/impressions_repository'
require 'splitclient-rb/cache/repositories/impressions/memory_repository'
require 'splitclient-rb/cache/repositories/impressions/redis_repository'
require 'splitclient-rb/cache/repositories/metrics_repository'
require 'splitclient-rb/cache/repositories/metrics/memory_repository'
require 'splitclient-rb/cache/repositories/metrics/redis_repository'
require 'splitclient-rb/cache/senders/impressions_formatter'
require 'splitclient-rb/cache/senders/impressions_sender'
require 'splitclient-rb/cache/senders/metrics_sender'
require 'splitclient-rb/cache/stores/sdk_blocker'
require 'splitclient-rb/cache/stores/segment_store'
require 'splitclient-rb/cache/stores/split_store'

require 'splitclient-rb/localhost_utils'
require 'splitclient-rb/clients/localhost_split_client'
require 'splitclient-rb/clients/split_client'
require 'splitclient-rb/managers/localhost_split_manager'
require 'splitclient-rb/managers/split_manager'
require 'splitclient-rb/split_factory'
require 'splitclient-rb/split_factory_builder'
require 'splitclient-rb/localhost_split_factory'
require 'splitclient-rb/split_config'

require 'splitclient-rb/engine/api/faraday_middleware/gzip'
require 'splitclient-rb/engine/api/client'
require 'splitclient-rb/engine/api/impressions'
require 'splitclient-rb/engine/api/metrics'
require 'splitclient-rb/engine/api/segments'
require 'splitclient-rb/engine/api/splits'
require 'splitclient-rb/engine/parser/condition'
require 'splitclient-rb/engine/parser/partition'
require 'splitclient-rb/engine/parser/split_adapter'
require 'splitclient-rb/engine/parser/evaluator'
require 'splitclient-rb/engine/matchers/combiners'
require 'splitclient-rb/engine/matchers/combining_matcher'
require 'splitclient-rb/engine/matchers/all_keys_matcher'
require 'splitclient-rb/engine/matchers/negation_matcher'
require 'splitclient-rb/engine/matchers/user_defined_segment_matcher'
require 'splitclient-rb/engine/matchers/whitelist_matcher'
require 'splitclient-rb/engine/matchers/equal_to_matcher'
require 'splitclient-rb/engine/matchers/greater_than_or_equal_to_matcher'
require 'splitclient-rb/engine/matchers/less_than_or_equal_to_matcher'
require 'splitclient-rb/engine/matchers/between_matcher'
require 'splitclient-rb/engine/matchers/set_matcher'
require 'splitclient-rb/engine/matchers/part_of_set_matcher'
require 'splitclient-rb/engine/matchers/equal_to_set_matcher'
require 'splitclient-rb/engine/matchers/contains_any_matcher'
require 'splitclient-rb/engine/matchers/contains_all_matcher'
require 'splitclient-rb/engine/matchers/starts_with_matcher'
require 'splitclient-rb/engine/matchers/ends_with_matcher'
require 'splitclient-rb/engine/matchers/contains_matcher'
require 'splitclient-rb/engine/matchers/dependency_matcher'
require 'splitclient-rb/engine/matchers/equal_to_boolean_matcher'
require 'splitclient-rb/engine/matchers/equal_to_matcher'
require 'splitclient-rb/engine/matchers/matches_string_matcher'
require 'splitclient-rb/engine/evaluator/splitter'
require 'splitclient-rb/engine/metrics/metrics'
require 'splitclient-rb/engine/metrics/binary_search_latency_tracker'
require 'splitclient-rb/engine/models/split'
require 'splitclient-rb/engine/models/label'
require 'splitclient-rb/engine/models/treatment'
require 'splitclient-rb/utilitites'

module SplitIoClient
  def self.root
    File.dirname(__dir__)
  end
end
