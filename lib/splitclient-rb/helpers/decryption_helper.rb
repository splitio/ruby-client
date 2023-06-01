# frozen_string_literal: true

module SplitIoClient
  NO_COMPRESSION = 0
  GZIP_COMPRESSION = 1
  ZLIB_COMPRESSION = 2

  module Helpers
    class DecryptionHelper
      def self.get_encoded_definition(compression, data)
        case compression
        when NO_COMPRESSION
          return Base64.decode64(data)
        when GZIP_COMPRESSION
          gz = Zlib::GzipReader.new(StringIO.new(Base64.decode64(data)))
          return gz.read
        when ZLIB_COMPRESSION
          return Zlib::Inflate.inflate(Base64.decode64(data))
        end
      end
    end
  end
end
