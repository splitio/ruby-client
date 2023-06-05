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
          Base64.decode64(data)
        when GZIP_COMPRESSION
          gz = Zlib::GzipReader.new(StringIO.new(Base64.decode64(data)))
          gz.read
        when ZLIB_COMPRESSION
          Zlib::Inflate.inflate(Base64.decode64(data))
        else
          raise StandardError, 'Compression flag value is incorrect'
        end
      end
    end
  end
end
