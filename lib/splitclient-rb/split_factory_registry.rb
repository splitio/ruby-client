require 'logger'
require 'socket'

module SplitIoClient

  class << self
      attr_accessor :split_factory_registry
  end

  def self.load_factory_registry
    self.split_factory_registry ||= SplitFactoryRegistry.new
  end

  #
  # This class manages configuration options for the split client library.
  # If not custom configuration is required the default configuration values will be used
  #
  class SplitFactoryRegistry

    attr_accessor :api_keys_hash

    def initialize
      @api_keys_hash = Hash.new
    end

    def add(api_key)
      return unless api_key

      @api_keys_hash[api_key] = 0 unless @api_keys_hash[api_key]
      @api_keys_hash[api_key] += 1
    end

    def remove(api_key)
      return unless api_key

      @api_keys_hash[api_key] -= 1 if @api_keys_hash[api_key]
      @api_keys_hash.delete(api_key) if @api_keys_hash[api_key] == 0
    end

    def number_of_factories_for(api_key)
      return 0 unless api_key
      return 0 unless @api_keys_hash.key?(api_key)

      @api_keys_hash[api_key]
    end

    def other_factories
      return !@api_keys_hash.empty?
    end

    def active_factories
      @api_keys_hash.length
    end

    def redundant_active_factories
      to_return = 0

      @api_keys_hash.each { |key| to_return += (key[1]-1) }

      to_return
    end
  end
end
