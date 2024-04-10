require 'forwardable'

require 'splitclient-rb/version'

require 'splitclient-rb/constants'
require 'splitclient-rb/exceptions'
require 'splitclient-rb/cache/routers/impression_router'
require 'splitclient-rb/cache/adapters/memory_adapters/map_adapter'
require 'splitclient-rb/cache/adapters/memory_adapters/queue_adapter'
require 'splitclient-rb/cache/adapters/cache_adapter'
require 'splitclient-rb/cache/adapters/memory_adapter'
require 'splitclient-rb/cache/adapters/redis_adapter'
require 'splitclient-rb/cache/fetchers/segment_fetcher'
require 'splitclient-rb/cache/fetchers/split_fetcher'
require 'splitclient-rb/cache/filter/bloom_filter'
require 'splitclient-rb/cache/filter/filter_adapter'
require 'splitclient-rb/cache/filter/flag_set_filter'
require 'splitclient-rb/cache/hashers/impression_hasher'
require 'splitclient-rb/cache/observers/impression_observer'
require 'splitclient-rb/cache/observers/noop_impression_observer'
require 'splitclient-rb/cache/repositories/repository'
require 'splitclient-rb/cache/repositories/segments_repository'
require 'splitclient-rb/cache/repositories/splits_repository'
require 'splitclient-rb/cache/repositories/events_repository'
require 'splitclient-rb/cache/repositories/impressions_repository'
require 'splitclient-rb/cache/repositories/events/memory_repository'
require 'splitclient-rb/cache/repositories/events/redis_repository'
require 'splitclient-rb/cache/repositories/flag_sets/memory_repository'
require 'splitclient-rb/cache/repositories/flag_sets/redis_repository'
require 'splitclient-rb/cache/repositories/impressions/memory_repository'
require 'splitclient-rb/cache/repositories/impressions/redis_repository'
require 'splitclient-rb/cache/senders/impressions_formatter'
require 'splitclient-rb/cache/senders/impressions_sender'
require 'splitclient-rb/cache/senders/events_sender'
require 'splitclient-rb/cache/senders/impressions_count_sender'
require 'splitclient-rb/cache/senders/localhost_repo_cleaner'
require 'splitclient-rb/cache/senders/impressions_sender_adapter'
require 'splitclient-rb/cache/senders/impressions_adapter/memory_sender'
require 'splitclient-rb/cache/senders/impressions_adapter/redis_sender'
require 'splitclient-rb/cache/stores/localhost_split_builder'
require 'splitclient-rb/cache/stores/localhost_split_store'
require 'splitclient-rb/cache/stores/store_utils'

require 'splitclient-rb/clients/split_client'
require 'splitclient-rb/managers/split_manager'
require 'splitclient-rb/helpers/thread_helper'
require 'splitclient-rb/helpers/decryption_helper'
require 'splitclient-rb/helpers/util'
require 'splitclient-rb/helpers/repository_helper'
require 'splitclient-rb/split_factory'
require 'splitclient-rb/split_factory_builder'
require 'splitclient-rb/split_config'
require 'splitclient-rb/split_logger'
require 'splitclient-rb/validators'
require 'splitclient-rb/split_factory_registry'

require 'splitclient-rb/engine/api/faraday_middleware/gzip'
require 'splitclient-rb/engine/api/client'
require 'splitclient-rb/engine/api/impressions'
require 'splitclient-rb/engine/api/segments'
require 'splitclient-rb/engine/api/splits'
require 'splitclient-rb/engine/api/events'
require 'splitclient-rb/engine/api/telemetry_api'
require 'splitclient-rb/engine/common/impressions_counter'
require 'splitclient-rb/engine/common/impressions_manager'
require 'splitclient-rb/engine/common/noop_impressions_counter'
require 'splitclient-rb/engine/parser/condition'
require 'splitclient-rb/engine/parser/partition'
require 'splitclient-rb/engine/parser/evaluator'
require 'splitclient-rb/engine/matchers/matcher'
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
require 'splitclient-rb/engine/matchers/semver'
require 'splitclient-rb/engine/matchers/equal_to_semver_matcher'
require 'splitclient-rb/engine/evaluator/splitter'
require 'splitclient-rb/engine/impressions/noop_unique_keys_tracker'
require 'splitclient-rb/engine/impressions/unique_keys_tracker'
require 'splitclient-rb/engine/metrics/binary_search_latency_tracker'
require 'splitclient-rb/engine/models/split'
require 'splitclient-rb/engine/models/label'
require 'splitclient-rb/engine/models/treatment'
require 'splitclient-rb/engine/auth_api_client'
require 'splitclient-rb/engine/back_off'
require 'splitclient-rb/engine/push_manager'
require 'splitclient-rb/engine/status_manager'
require 'splitclient-rb/engine/sync_manager'
require 'splitclient-rb/engine/synchronizer'
require 'splitclient-rb/utilitites'

# SSE
require 'splitclient-rb/sse/event_source/client'
require 'splitclient-rb/sse/event_source/event_parser'
require 'splitclient-rb/sse/event_source/event_types'
require 'splitclient-rb/sse/event_source/stream_data'
require 'splitclient-rb/sse/workers/segments_worker'
require 'splitclient-rb/sse/workers/splits_worker'
require 'splitclient-rb/sse/notification_manager_keeper'
require 'splitclient-rb/sse/notification_processor'
require 'splitclient-rb/sse/sse_handler'

# Telemetry
require 'splitclient-rb/telemetry/domain/constants'
require 'splitclient-rb/telemetry/domain/structs'
require 'splitclient-rb/telemetry/storages/memory'
require 'splitclient-rb/telemetry/evaluation_consumer'
require 'splitclient-rb/telemetry/evaluation_producer'
require 'splitclient-rb/telemetry/init_consumer'
require 'splitclient-rb/telemetry/init_producer'
require 'splitclient-rb/telemetry/runtime_consumer'
require 'splitclient-rb/telemetry/runtime_producer'
require 'splitclient-rb/telemetry/sync_task'
require 'splitclient-rb/telemetry/synchronizer'
require 'splitclient-rb/telemetry/memory/memory_evaluation_consumer'
require 'splitclient-rb/telemetry/memory/memory_evaluation_producer'
require 'splitclient-rb/telemetry/memory/memory_init_consumer'
require 'splitclient-rb/telemetry/memory/memory_init_producer'
require 'splitclient-rb/telemetry/memory/memory_runtime_consumer'
require 'splitclient-rb/telemetry/memory/memory_runtime_producer'
require 'splitclient-rb/telemetry/memory/memory_synchronizer'
require 'splitclient-rb/telemetry/redis/redis_evaluation_producer'
require 'splitclient-rb/telemetry/redis/redis_init_producer'
require 'splitclient-rb/telemetry/redis/redis_synchronizer'

# C extension
require 'murmurhash/murmurhash_mri'

module SplitIoClient
  def self.root
    File.dirname(__dir__)
  end
end
