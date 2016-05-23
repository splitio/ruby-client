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
    # @option opts [Object] :local_store A cache store for the Faraday HTTP caching library. Defaults to the Rails cache in a Rails environment, or a thread-safe in-memory store otherwise.
    # @option opts [Int] :features_refresh_rate The SDK polls Split servers for changes to feature roll-out plans. This parameter controls this polling period in seconds.
    # @option opts [Int] :segments_refresh_rate
    # @option opts [Int] :metrics_refresh_rate
    # @option opts [Int] :impressions_refresh_rate
    # @option opts [Object] :logger a logger to user for messages from the client. Defaults to stdout
    # @option opts [Boolean] :debug_enabled (false) The value for the debug flag
    #
    # @return [type] SplitConfig with configuration options
    def initialize(opts = {})
      @base_uri = (opts[:base_uri] || SplitConfig.default_base_uri).chomp('/')
      @events_uri = (opts[:events_uri] || SplitConfig.default_events_uri).chomp('/')
      @local_store = opts[:local_store] || SplitConfig.default_local_store
      @connection_timeout = opts[:connection_timeout] || SplitConfig.default_connection_timeout
      @read_timeout = opts[:read_timeout] || SplitConfig.default_read_timeout
      @features_refresh_rate = opts[:features_refresh_rate] || SplitConfig.default_features_refresh_rate
      @segments_refresh_rate = opts[:segments_refresh_rate] || SplitConfig.default_segments_refresh_rate
      @metrics_refresh_rate = opts[:metrics_refresh_rate] || SplitConfig.default_metrics_refresh_rate
      @impressions_refresh_rate = opts[:impressions_refresh_rate] || SplitConfig.default_impressions_refresh_rate
      @logger = opts[:logger] || SplitConfig.default_logger
      @debug_enabled = opts[:debug_enabled] || SplitConfig.default_debug
      @machine_name = SplitConfig.get_hostname
      @machine_ip = SplitConfig.get_ip
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
    # The store for the Faraday HTTP caching library. Stores should respond to
    # 'read', 'write' and 'delete' requests.
    #
    # @return [Object] The configured store for the Faraday HTTP caching library.
    attr_reader :local_store

    #
    # The read timeout for network connections in seconds.
    #
    # @return [Int] The timeout in seconds.
    attr_reader :read_timeout

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

    attr_reader :machine_ip
    attr_reader :machine_name

    attr_reader :features_refresh_rate
    attr_reader :segments_refresh_rate
    attr_reader :metrics_refresh_rate
    attr_reader :impressions_refresh_rate

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

    # @return [LocalStore] configuration value for local cache store
    def self.default_local_store
      defined?(Rails) && Rails.respond_to?(:cache) ? Rails.cache : LocalStore.new
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

    #
    # The default logger object
    #
    # @return [object]
    def self.default_logger
      Logger.new($stdout)
    end

    #
    # The default debug value
    #
    # @return [boolean]
    def self.default_debug
      false
    end

    #
    # custom logger of exceptions
    #
    # @return [void]
    def log_found_exception(caller, exn)
      error_traceback = "#{exn.inspect} #{exn}\n\t#{exn.backtrace.join("\n\t")}"
      error = "[splitclient-rb] Unexpected exception in #{caller}: #{error_traceback}"
      @logger.error(error)
    end

    #
    # gets the hostname where the sdk gem is running
    #
    # @return [string]
    def self.get_hostname
      begin
        Socket.gethostname
      rescue
        #unable to get hostname
        'localhost'
      end
    end

    #
    # gets the ip where the sdk gem is running
    #
    # @return [string]
    def self.get_ip
      begin
        Socket::getaddrinfo(Socket.gethostname, 'echo', Socket::AF_INET)[0][3]
      rescue
        #unable to get local ip
        '127.0.0.0'
      end
    end

  end
end
