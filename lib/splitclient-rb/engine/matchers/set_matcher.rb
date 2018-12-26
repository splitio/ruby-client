# frozen_string_literal: true

require 'set'

module SplitIoClient
  class SetMatcher
    protected

    def initialize(attribute, remote_array)
      @attribute = attribute
      @remote_set = remote_array.to_set
    end

    def local_set(data, attribute)
      data = data.fetch(attribute) { |a| data[a.to_s] || data[a.to_sym] }
      # Allow user to pass individual elements as well
      local_array = data.is_a?(Array) ? data : [data]

      local_array.to_set
    end
  end
end
