# frozen_string_literal: true

module SplitIoClient
  module Helpers
    class DecryptionHelper
      def self.get_encoded_definition(compression, data)
        case compression
        when 0
          return Base64.decode64(data)
        when 1
          gz = Zlib::GzipReader.new(StringIO.new(Base64.decode64(data)))
          return gz.read
        when 2
          return Zlib::Inflate.inflate(Base64.decode64(data))
        end
      end
    end
  end
end
