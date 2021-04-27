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
    # @option opts [Int] :cache_ttl Time to live in seconds for the memory cache values when using Redis.
    # @option opts [Int] :max_cache_size Max number of items to be held in the memory cache before prunning when using Redis.
    # @return [type] SplitConfig with configuration options
    def initialize(opts = {})
      @base_uri = (opts[:base_uri] || SplitConfig.default_base_uri).chomp('/')
      @events_uri = (opts[:events_uri] || SplitConfig.default_events_uri).chomp('/')
      @mode = opts[:mode] || SplitConfig.default_mode
      @redis_url = opts[:redis_url] || SplitConfig.default_redis_url
      @redis_namespace = opts[:redis_namespace] && opts[:redis_namespace].to_s.length > 0 ? "#{opts[:redis_namespace]}.#{SplitConfig.default_redis_namespace}" : SplitConfig.default_redis_namespace
      @cache_adapter = SplitConfig.init_cache_adapter(
        opts[:cache_adapter] || SplitConfig.default_cache_adapter, :map_adapter, nil, @redis_url
      )
      @connection_timeout = opts[:connection_timeout] || SplitConfig.default_connection_timeout
      @read_timeout = opts[:read_timeout] || SplitConfig.default_read_timeout

      @logger = opts[:logger] || SplitConfig.default_logger

      if(opts[:reload_rate])
        @features_refresh_rate = opts[:reload_rate]
        @logger.warn('Localhost mode: reload_rate will be deprecated soon in favor of ' \
          'features_refresh_rate. Take a look in our documentation.'
        )
      else
        @features_refresh_rate = opts[:features_refresh_rate] || SplitConfig.default_features_refresh_rate
      end

      @segments_refresh_rate = opts[:segments_refresh_rate] || SplitConfig.default_segments_refresh_rate
      @metrics_refresh_rate = opts[:metrics_refresh_rate] || SplitConfig.default_metrics_refresh_rate

      @impressions_mode = init_impressions_mode(opts[:impressions_mode])

      @impressions_refresh_rate = SplitConfig.init_impressions_refresh_rate(@impressions_mode, opts[:impressions_refresh_rate], SplitConfig.default_impressions_refresh_rate)
      @impressions_queue_size = opts[:impressions_queue_size] || SplitConfig.default_impressions_queue_size
      @impressions_adapter = SplitConfig.init_cache_adapter(
        opts[:cache_adapter] || SplitConfig.default_cache_adapter, :queue_adapter, @impressions_queue_size, @redis_url
      )
      #Safeguard for users of older SDK versions.
      @impressions_bulk_size = opts[:impressions_bulk_size] || @impressions_queue_size > 0 ? @impressions_queue_size : 0

      @debug_enabled = opts[:debug_enabled] || SplitConfig.default_debug
      @transport_debug_enabled = opts[:transport_debug_enabled] || SplitConfig.default_debug
      @block_until_ready = SplitConfig.default_block_until_ready

      @ip_addresses_enabled = opts[:ip_addresses_enabled].nil? ? SplitConfig.default_ip_addresses_enabled : opts[:ip_addresses_enabled]

      @machine_name = SplitConfig.machine_hostname(@ip_addresses_enabled, opts[:machine_name], opts[:cache_adapter] || SplitConfig.default_cache_adapter)
      @machine_ip = SplitConfig.machine_ip(@ip_addresses_enabled, opts[:machine_ip], opts[:cache_adapter] || SplitConfig.default_cache_adapter)

      @cache_ttl = opts[:cache_ttl] || SplitConfig.cache_ttl
      @max_cache_size = opts[:max_cache_size] || SplitConfig.max_cache_size

      @language = opts[:language] || 'ruby'
      @version = opts[:version] || SplitIoClient::VERSION

      @labels_enabled = opts[:labels_enabled].nil? ? SplitConfig.default_labels_logging : opts[:labels_enabled]

      @impression_listener = opts[:impression_listener]
      @impression_listener_refresh_rate = opts[:impression_listener_refresh_rate] || SplitConfig.default_impression_listener_refresh_rate

      @max_key_size = SplitConfig.max_key_size

      @threads = {}

      @events_push_rate = opts[:events_push_rate] || SplitConfig.default_events_push_rate
      @events_queue_size = opts[:events_queue_size] || SplitConfig.default_events_queue_size
      @events_adapter = SplitConfig.init_cache_adapter(
        opts[:cache_adapter] || SplitConfig.default_cache_adapter, :queue_adapter, @events_queue_size, @redis_url
      )

      @split_file = opts[:split_file] || SplitConfig.default_split_file

      @valid_mode = true
      @split_logger = SplitIoClient::SplitLogger.new(self)
      @split_validator = SplitIoClient::Validators.new(self)
      @localhost_mode = opts[:localhost_mode]

      @streaming_enabled = consumer? ? false : (opts[:streaming_enabled].nil? ? SplitConfig.default_streaming_enabled : opts[:streaming_enabled])
      @streaming_service_url = opts[:streaming_service_url] || SplitConfig.default_streaming_service_url
      @auth_service_url = opts[:auth_service_url] || SplitConfig.default_auth_service_url
      @auth_retry_back_off_base = SplitConfig.init_auth_retry_back_off(opts[:auth_retry_back_off_base] || SplitConfig.default_auth_retry_back_off_base)
      @streaming_reconnect_back_off_base = SplitConfig.init_streaming_reconnect_back_off(opts[:streaming_reconnect_back_off_base] || SplitConfig.default_streaming_reconnect_back_off_base)

      startup_log
    end

    #
    # The base URL for split API end points
    #
    # @return [String] The configured base URL for the split API end points
    attr_accessor :base_uri

    #
    # The base URL for split events API end points
    #
    # @return [String] The configured URL for the events API end points
    attr_accessor :events_uri

    #
    # The mode SDK will run
    #
    # @return [Symbol] One of the available SDK modes: standalone, consumer
    attr_accessor :mode

    # The read timeout for network connections in seconds.
    #
    # @return [Int] The timeout in seconds.
    attr_accessor :read_timeout

    #
    # The cache adapter to store splits/segments in
    #
    # @return [Object] Cache adapter instance
    attr_accessor :cache_adapter

    #
    # The cache adapter to store impressions in
    #
    # @return [Object] Impressions adapter instance
    attr_accessor :impressions_adapter

    #
    # The cache adapter to store events in
    #
    # @return [Object] Metrics adapter
    attr_accessor :events_adapter

    #
    # The connection timeout for network connections in seconds.
    #
    # @return [Int] The connect timeout in seconds.
    attr_accessor :connection_timeout

    #
    # The configured logger. The client library uses the log to
    # print warning and error messages.
    #
    # @return [Logger] The configured logger
    attr_accessor :logger

    #
    # The split logger. The client library uses the split logger
    # to use common functions around the logger
    #
    # @return [SplitLogger] The configured logger
    attr_accessor :split_logger

    #
    # The split validator. The client library uses the split validator
    # to validate inputs accross the sdk
    #
    # @return [SplitValidator] The validator
    attr_accessor :split_validator

    #
    # The boolean that represents the state of the debug log level
    #
    # @return [Boolean] The value for the debug flag
    attr_accessor :debug_enabled

    #
    # Enable to log the content retrieved from endpoints
    #
    # @return [Boolean] The value for the debug flag
    attr_accessor :transport_debug_enabled

    #
    # Enable logging labels and sending potentially sensitive information
    #
    # @return [Boolean] The value for the labels enabled flag
    attr_accessor :labels_enabled

    #
    # The number of seconds to wait for SDK readiness
    # or false to disable waiting
    # @return [Integer]/[FalseClass]
    attr_accessor :block_until_ready

    attr_accessor :machine_ip
    attr_accessor :machine_name

    attr_accessor :cache_ttl
    attr_accessor :max_cache_size

    attr_accessor :max_key_size

    attr_accessor :language
    attr_accessor :version

    attr_accessor :features_refresh_rate
    attr_accessor :segments_refresh_rate
    attr_accessor :metrics_refresh_rate
    attr_accessor :impressions_refresh_rate

    attr_accessor :impression_listener
    attr_accessor :impression_listener_refresh_rate

    #
    # How big the impressions queue is before dropping impressions
    #
    # @return [Integer]
    attr_accessor :impressions_queue_size
    attr_accessor :impressions_bulk_size

    attr_accessor :redis_url
    attr_accessor :redis_namespace

    attr_accessor :threads

    attr_accessor :valid_mode

    #
    # The schedule time for events flush after the first one
    #
    # @return [Integer]
    attr_accessor :events_push_rate

    #
    # The max size of the events queue
    #
    # @return [Integer]
    attr_accessor :events_queue_size

    attr_accessor :split_file

    attr_accessor :localhost_mode

    attr_accessor :ip_addresses_enabled

    attr_accessor :auth_service_url

    attr_accessor :auth_retry_back_off_base

    attr_accessor :streaming_service_url

    attr_accessor :streaming_reconnect_back_off_base

    attr_accessor :streaming_enabled

    attr_accessor :impressions_mode

    def self.default_impressions_mode
      :optimized
    end

    def init_impressions_mode(impressions_mode)
      impressions_mode ||= SplitConfig.default_impressions_mode

      case impressions_mode
      when :debug
        return :debug
      else
        @logger.error('You passed an invalid impressions_mode, impressions_mode should be one of the following values: :debug or :optimized. Defaulting to :optimized mode') unless impressions_mode == :optimized
        return :optimized
      end
    end

    def self.init_impressions_refresh_rate(impressions_mode, refresh_rate, default_rate)      
      return (refresh_rate.nil? || refresh_rate <= 0 ? default_rate : refresh_rate) if impressions_mode == :debug
      
      return refresh_rate.nil? || refresh_rate <= 0 ? SplitConfig.default_impressions_refresh_rate_optimized : [default_rate, refresh_rate].max
    end

    def self.default_streaming_enabled
      true
    end

    def self.default_streaming_service_url
      'https://streaming.split.io/event-stream'
    end

    def self.default_auth_service_url
      'https://auth.split.io/api/auth'
    end

    def self.default_auth_retry_back_off_base
      1
    end

    def self.default_streaming_reconnect_back_off_base
      1
    end

    def self.init_auth_retry_back_off(auth_retry_back_off)
      auth_retry_back_off < 1 ? SplitConfig.default_auth_retry_back_off_base : auth_retry_back_off
    end

    def self.init_streaming_reconnect_back_off(streaming_reconnect_back_off)
      streaming_reconnect_back_off < 1 ? SplitConfig.default_streaming_reconnect_back_off_base : streaming_reconnect_back_off
    end

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

    def self.init_cache_adapter(adapter, data_structure, queue_size = nil, redis_url = nil)
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
      5
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

    def self.default_impressions_refresh_rate_optimized
      300
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

    def self.default_split_file
      File.join(Dir.home, '.split')
    end

    def self.default_offline_refresh_rate
      5
    end

    #
    # The default logger object
    #
    # @return [object]
    def self.default_logger
      if defined?(Rails) && Rails.logger
        Rails.logger
      elsif ENV['SPLITCLIENT_ENV'] == 'test'
        Logger.new('/dev/null')
      else
       Logger.new($stdout)
       end
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
    # The default block until ready value
    #
    # @return [int]
    def self.default_block_until_ready
      15
    end

    #
    # The default ip addresses enabled value
    #
    # @return [boolean]
    def self.default_ip_addresses_enabled
      true
    end

    #
    # The default transport_debug_enabled value
    #
    # @return [boolean]
    def self.transport_debug
      false
    end

    #
    # The default cache time to live
    #
    # @return [int]
    def self.cache_ttl
      5
    end

    # The default max cache size
    #
    # @return [int]
    def self.max_cache_size
      500
    end

    # The default max key size
    #
    # @return [int]
    def self.max_key_size
      250
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

    def standalone?
      @mode.equal?(:standalone)
    end

    def consumer?
      @mode.equal?(:consumer)
    end

    #
    # gets the hostname where the sdk gem is running
    #
    # @return [string]
    def self.machine_hostname(ip_addresses_enabled, machine_name, adapter)
      if ip_addresses_enabled
        begin
          return machine_name || Socket.gethostname
        rescue
          return 'unknown'.freeze
        end
      else
        case adapter
        when :redis
          return 'NA'.freeze
        end
      end
      
      return ''.freeze
    end

    #
    # gets the ip where the sdk gem is running
    #
    # @return [string]
    def self.machine_ip(ip_addresses_enabled, ip, adapter)
      if ip_addresses_enabled
        begin          
          return ip unless ip.nil? || ip.to_s.empty?

          loopback_ip = Socket.ip_address_list.find { |ip| ip.ipv4_loopback? }
          private_ip = Socket.ip_address_list.find { |ip| ip.ipv4_private? }

          addr_info = private_ip || loopback_ip

          return addr_info.ip_address
        rescue
          return 'unknown'.freeze
        end
      else
        case adapter
        when :redis
          return 'NA'.freeze
        end
      end

      return ''.freeze
    end
  end
end
