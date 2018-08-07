require 'logger'
require 'socket'

module SplitIoClient
  #
  # This class manages configuration options for the split client library.
  # If not custom configuration is required the default configuration values will be used
  #
  class SplitConfig
    #
    # Constructor for creating custom split client config
    #
    # @param opts [Hash] optional hash with configuration options
    # @option opts [String] :base_uri ("https://sdk.split.io/api/") The base URL for split API end points
    # @option opts [String] :events_uri ("https://events.split.io/api/") The events URL for events end points
    # @option opts [Int] :read_timeout (10) The read timeout for network connections in seconds.
    # @option opts [Int] :connection_timeout (2) The connect timeout for network connections in seconds.
    # @option opts [Int] :features_refresh_rate The SDK polls Split servers for changes to feature roll-out plans. This parameter controls this polling period in seconds.
    # @option opts [Int] :segments_refresh_rate
    # @option opts [Int] :metrics_refresh_rate
    # @option opts [Int] :impressions_refresh_rate
    # @option opts [Object] :logger a logger to user for messages from the client. Defaults to stdout
    # @option opts [Boolean] :debug_enabled (false) The value for the debug flag
    # @option opts [Int] :impressions_queue_size Size of the impressions queue in the memory repository. Once reached, newer impressions will be dropped
    # @option opts [Int] :impressions_bulk_size Max number of impressions to be sent to the backend on each post
    # @option opts [#log] :impression_listener this object will capture all impressions and process them through `#log`
    # @return [type] SplitConfig with configuration options
    def initialize(opts = {})
      @base_uri = (opts[:base_uri] || SplitConfig.default_base_uri).chomp('/')
      @events_uri = (opts[:events_uri] || SplitConfig.default_events_uri).chomp('/')
      @mode = opts[:mode] || SplitConfig.default_mode
      @redis_url = opts[:redis_url] || SplitConfig.default_redis_url
      @redis_namespace = opts[:redis_namespace] ? "#{opts[:redis_namespace]}.#{SplitConfig.default_redis_namespace}" : SplitConfig.default_redis_namespace
      @cache_adapter = SplitConfig.init_cache_adapter(
        opts[:cache_adapter] || SplitConfig.default_cache_adapter, :map_adapter, @redis_url, false
      )
      @connection_timeout = opts[:connection_timeout] || SplitConfig.default_connection_timeout
      @read_timeout = opts[:read_timeout] || SplitConfig.default_read_timeout
      @features_refresh_rate = opts[:features_refresh_rate] || SplitConfig.default_features_refresh_rate
      @segments_refresh_rate = opts[:segments_refresh_rate] || SplitConfig.default_segments_refresh_rate
      @metrics_refresh_rate = opts[:metrics_refresh_rate] || SplitConfig.default_metrics_refresh_rate

      @impressions_refresh_rate = opts[:impressions_refresh_rate] || SplitConfig.default_impressions_refresh_rate
      @impressions_queue_size = opts[:impressions_queue_size] || SplitConfig.default_impressions_queue_size
      @impressions_adapter = SplitConfig.init_cache_adapter(
        opts[:cache_adapter] || SplitConfig.default_cache_adapter, :queue_adapter, @redis_url, @impressions_queue_size
      )
      #Safeguard for users of older SDK versions.
      @disable_impressions = @impressions_queue_size == -1
      #Safeguard for users of older SDK versions.
      @impressions_bulk_size = opts[:impressions_bulk_size] || @impressions_queue_size > 0 ? @impressions_queue_size : 0

      @metrics_adapter = SplitConfig.init_cache_adapter(
        opts[:cache_adapter] || SplitConfig.default_cache_adapter, :map_adapter, @redis_url, false
      )

      @logger = opts[:logger] || SplitConfig.default_logger
      @debug_enabled = opts[:debug_enabled] || SplitConfig.default_debug
      @transport_debug_enabled = opts[:transport_debug_enabled] || SplitConfig.default_debug
      @block_until_ready = opts[:ready] || opts[:block_until_ready] || 0
      @machine_name = opts[:machine_name] || SplitConfig.machine_hostname
      @machine_ip = opts[:machine_ip] || SplitConfig.machine_ip

      @language = opts[:language] || 'ruby'
      @version = opts[:version] || SplitIoClient::VERSION

      @labels_enabled = opts[:labels_enabled].nil? ? SplitConfig.default_labels_logging : opts[:labels_enabled]

      @impression_listener = opts[:impression_listener]
      @impression_listener_refresh_rate = opts[:impression_listener_refresh_rate] || SplitConfig.default_impression_listener_refresh_rate

      @threads = {}

      @events_push_rate = opts[:events_push_rate] || SplitConfig.default_events_push_rate
      @events_queue_size = opts[:events_queue_size] || SplitConfig.default_events_queue_size
      @events_adapter = SplitConfig.init_cache_adapter(
        opts[:cache_adapter] || SplitConfig.default_cache_adapter, :queue_adapter, @redis_url, @events_queue_size
      )

      startup_log
    end

    #
    # The base URL for split API end points
    #
    # @return [String] The configured base URL for the split API end points
    attr_reader :base_uri

    #
    # The base URL for split events API end points
    #
    # @return [String] The configured URL for the events API end points
    attr_reader :events_uri

    #
    # The mode SDK will run
    #
    # @return [Symbol] One of the available SDK modes: standalone, consumer, producer
    attr_reader :mode

    # The read timeout for network connections in seconds.
    #
    # @return [Int] The timeout in seconds.
    attr_reader :read_timeout

    #
    # The cache adapter to store splits/segments in
    #
    # @return [Object] Cache adapter instance
    attr_reader :cache_adapter

    #
    # The cache adapter to store impressions in
    #
    # @return [Object] Impressions adapter instance
    attr_reader :impressions_adapter

    #
    # The cache adapter to store metrics in
    #
    # @return [Symbol] Metrics adapter
    attr_reader :metrics_adapter

    #
    # The cache adapter to store events in
    #
    # @return [Object] Metrics adapter
    attr_reader :events_adapter

    #
    # The connection timeout for network connections in seconds.
    #
    # @return [Int] The connect timeout in seconds.
    attr_reader :connection_timeout

    #
    # The configured logger. The client library uses the log to
    # print warning and error messages.
    #
    # @return [Logger] The configured logger
    attr_reader :logger

    #
    # The boolean that represents the state of the debug log level
    #
    # @return [Boolean] The value for the debug flag
    attr_reader :debug_enabled

    #
    # Enable to log the content retrieved from endpoints
    #
    # @return [Boolean] The value for the debug flag
    attr_reader :transport_debug_enabled

    #
    # Enable logging labels and sending potentially sensitive information
    #
    # @return [Boolean] The value for the labels enabled flag
    attr_reader :labels_enabled

    #
    # The number of seconds to wait for SDK readiness
    # or false to disable waiting
    # @return [Integer]/[FalseClass]
    attr_reader :block_until_ready

    attr_reader :machine_ip
    attr_reader :machine_name

    attr_reader :language
    attr_reader :version

    attr_reader :features_refresh_rate
    attr_reader :segments_refresh_rate
    attr_reader :metrics_refresh_rate
    attr_reader :impressions_refresh_rate

    attr_reader :impression_listener
    attr_reader :impression_listener_refresh_rate

    #
    # How big the impressions queue is before dropping impressions. -1 to disable it.
    #
    # @return [Integer]
    attr_reader :impressions_queue_size
    attr_reader :impressions_bulk_size
    attr_reader :disable_impressions

    attr_reader :redis_url
    attr_reader :redis_namespace

    attr_accessor :threads

    #
    # The schedule time for events flush after the first one
    #
    # @return [Integer]
    attr_reader :events_push_rate

    #
    # The max size of the events queue
    #
    # @return [Integer]
    attr_reader :events_queue_size

    #
    # The default split client configuration
    #
    # @return [Config] The default split client configuration.
    def self.default
      SplitConfig.new
    end

    #
    # The default base uri for api calls
    #
    # @return [string] The default base uri
    def self.default_base_uri
      'https://sdk.split.io/api/'
    end

    def self.default_events_uri
      'https://events.split.io/api/'
    end

    def self.init_cache_adapter(adapter, data_structure, redis_url = nil, queue_size = nil)
      case adapter
      when :memory
        SplitIoClient::Cache::Adapters::MemoryAdapter.new(map_memory_adapter(data_structure, queue_size))
      when :redis
        begin
          require 'redis'
        rescue LoadError
          fail StandardError, 'To use Redis as a cache adapter you must include it in your Gemfile'
        end

        SplitIoClient::Cache::Adapters::RedisAdapter.new(redis_url)
      end
    end

    def self.map_memory_adapter(name, queue_size)
      case name
      when :map_adapter
        SplitIoClient::Cache::Adapters::MemoryAdapters::MapAdapter.new
      when :queue_adapter
        SplitIoClient::Cache::Adapters::MemoryAdapters::QueueAdapter.new(queue_size)
      end
    end

    def self.default_mode
      :standalone
    end

    # @return [LocalStore] configuration value for local cache store
    def self.default_cache_adapter
      :memory
    end

    def self.default_metrics_adapter
      :memory
    end

    #
    # The default read timeout value
    #
    # @return [int]
    def self.default_read_timeout
      5
    end

    #
    # The default connection timeout value
    #
    # @return [int]
    def self.default_connection_timeout
      5
    end

    def self.default_features_refresh_rate
      30
    end

    def self.default_segments_refresh_rate
      60
    end

    def self.default_metrics_refresh_rate
      60
    end

    def self.default_impressions_refresh_rate
      60
    end

    def self.default_impression_listener_refresh_rate
      0
    end

    def self.default_impressions_queue_size
      5000
    end

    def self.default_events_push_rate
      60
    end

    def self.default_events_queue_size
      500
    end

    #
    # The default logger object
    #
    # @return [object]
    def self.default_logger
      (defined?(Rails) && Rails.logger) ? Rails.logger : Logger.new($stdout)
    end

    #
    # The default debug value
    #
    # @return [boolean]
    def self.default_debug
      false
    end

    #
    # The default labels logging value
    #
    # @return [boolean]
    def self.default_labels_logging
      true
    end

    def self.default_redis_url
      'redis://127.0.0.1:6379/0'
    end

    def self.default_redis_namespace
      'SPLITIO'
    end

    #
    # The default transport_debug_enabled value
    #
    # @return [boolean]
    def self.transport_debug
      false
    end

    #
    # custom logger of exceptions
    #
    # @return [void]
    def log_found_exception(caller, error)
      message = ''

      message << "[splitclient-rb] Unexpected exception in #{caller}: #{error.inspect} #{error}"
      message << "\n\t#{error.backtrace.join("\n\t")}" if @debug_enabled

      @logger.warn(message)
    end

    #
    # log which cache class was loaded and SDK mode
    #
    # @return [void]
    def startup_log
      return if ENV['SPLITCLIENT_ENV'] == 'test'

      @logger.info("Loaded Ruby SDK v#{VERSION} in the #{@mode} mode")
      @logger.info("Loaded cache class: #{@cache_adapter.class}")
    end

    #
    # gets the hostname where the sdk gem is running
    #
    # @return [string]
    def self.machine_hostname
      Socket.gethostname
    rescue
      'localhost'.freeze
    end

    #
    # gets the ip where the sdk gem is running
    #
    # @return [string]
    def self.machine_ip
      loopback_ip = Socket.ip_address_list.find { |ip| ip.ipv4_loopback? }
      private_ip = Socket.ip_address_list.find { |ip| ip.ipv4_private? }

      addr_info = private_ip || loopback_ip

      addr_info.ip_address
    end
  end
end
