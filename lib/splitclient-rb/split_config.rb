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
    # @option opts [Int] :timeout (10) The read timeout for network connections in seconds.
    # @option opts [Int] :connection_timeout (2) The connect timeout for network connections in seconds.
    # @option opts [Object] :local_store A cache store for the Faraday HTTP caching library. Defaults to the Rails cache in a Rails environment, or a
    #   thread-safe in-memory store otherwise.
    # @option opts [Int] :fetch_interval (60) The time interval for execution API refresh
    # @option opts [Int] :push_interval (180) The time interval for execution API pushes
    # @option opts [Object] :logger a logger to user for messages from the client. Defaults to stdout
    #
    # @return [type] SplitConfig with configuration options
    def initialize(opts = {})
      @base_uri = (opts[:base_uri] || SplitConfig.default_base_uri).chomp('/')
      @local_store = opts[:local_store] || SplitConfig.default_local_store
      @connection_timeout = opts[:connection_timeout] || SplitConfig.default_connection_timeout
      @timeout = opts[:timeout] || SplitConfig.default_timeout
      @fetch_interval = opts[:fetch_interval] || SplitConfig.default_fetch_interval
      @push_interval = opts[:push_interval] || SplitConfig.default_push_interval
      @logger = opts[:logger] || SplitConfig.default_logger
      @machine_name = SplitConfig.get_hostname
      @machine_ip = SplitConfig.get_ip
    end

    #
    # The base URL for split API end points
    #
    # @return [String] The configured base URL for the split API end points
    attr_reader :base_uri

    #
    # The store for the Faraday HTTP caching library. Stores should respond to
    # 'read', 'write' and 'delete' requests.
    #
    # @return [Object] The configured store for the Faraday HTTP caching library.
    attr_reader :local_store

    #
    # The timeout for network connections in seconds.
    #
    # @return [Int] The timeout in seconds.
    attr_reader :timeout

    #
    # The connection timeout for network connections in seconds.
    #
    # @return [Int] The connect timeout in seconds.
    attr_reader :connection_timeout

    #
    # The time interval for execution of API refresh calls
    #
    # @return [Int] The time execution interval in seconds.
    attr_reader :fetch_interval

    #
    # The time interval for execution of API push calls
    #
    # @return [Int] The time interval in seconds.
    attr_reader :push_interval

    #
    # The configured logger. The client library uses the log to
    # print warning and error messages.
    #
    # @return [Logger] The configured logger
    attr_reader :logger

    attr_reader :machine_ip
    attr_reader :machine_name

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

    # @return [LocalStore] configuration value for local cache store
    def self.default_local_store
      defined?(Rails) && Rails.respond_to?(:cache) ? Rails.cache : LocalStore.new
    end

    #
    # The default timeout value
    #
    # @return [int]
    def self.default_timeout
      5
    end

    #
    # The default connection timeout value
    #
    # @return [int]
    def self.default_connection_timeout
      2
    end

    #
    # The default fetch interval for splits and segments
    #
    # @return [int]
    def self.default_fetch_interval
      60
    end

    #
    # The default push interval for metrics
    #
    # @return [int]
    def self.default_push_interval
      180
    end

    #
    # The default logger object
    #
    # @return [object]
    def self.default_logger
      Logger.new($stdout)
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
      if
      Socket.gethostname
    end

    #
    # gets the ip where the sdk gem is running
    #
    # @return [string]
    def self.get_ip
      Socket::getaddrinfo(Socket.gethostname, 'echo', Socket::AF_INET)[0][3]
    end

  end
end