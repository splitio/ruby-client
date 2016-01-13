module SplitIoClient
  #
  # This class manages configuration options for the split client library.
  # If not custom configuration is required the default configuration values will be used
  #
  class SplitConfig
    #
    # Constructor for creating custom split client config
    #
    # @param opts [Hash] optional hasg with configuration options
    # @option opts [String] :base_uri ("https://sdk.split.io/api/") The base URL for split API end points
    # @option opts [Int] :timeout (10) The read timeout for network connections in seconds.
    # @option opts [Int] :connection_timeout (2) The connect timeout for network connections in seconds.
    # @option opts [Object] :local_store A cache store for the Faraday HTTP caching library. Defaults to the Rails cache in a Rails environment, or a
    # @option opts [Int] :exec_interval (10) The time interval for execution API refresh
    #   thread-safe in-memory store otherwise.
    #
    # @return [type] SplitConfig with configuration options
    def initialize(opts = {})
      @base_uri = (opts[:base_uri] || SplitConfig.default_base_uri).chomp("/")
      @local_store = opts[:local_store] || SplitConfig.default_local_store
      @connection_timeout = opts[:connection_timeout] || SplitConfig.default_connection_timeout
      @timeout = opts[:timeout] || SplitConfig.default_timeout
      @exec_interval = opts[:exec_interval] || SplitConfig.default_exec_interval
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
    # @return [Int] The time exection interval in seconds.
    attr_reader :exec_interval

    #
    # The default split client configuration
    #
    # @return [Config] The default split client configuration.
    def self.default
      SplitConfig.new
    end


    def self.default_base_uri
      #"https://sdk.split.io/api/"
      "http://localhost:8081/api/"
    end

    # @return [LocalStore] configuration value for local cache store
    def self.default_local_store
      defined?(Rails) && Rails.respond_to?(:cache) ? Rails.cache : LocalStore.new
    end


    def self.default_timeout
      10
    end

    def self.default_connection_timeout
      2
    end

    def self.default_exec_interval
      60
    end

  end
end