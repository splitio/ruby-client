require 'faraday'

module SplitIoClient
  module FaradayMiddleware
    class Gzip < Faraday::Middleware
      ACCEPT_ENCODING = 'Accept-Encoding'.freeze
      CONTENT_ENCODING = 'Content-Encoding'.freeze
      CONTENT_LENGTH = 'Content-Length'.freeze
      SUPPORTED_ENCODINGS = 'gzip,deflate'.freeze
      RUBY_ENCODING = '1.9'.respond_to?(:force_encoding)

      def call(env)
        env[:request_headers][ACCEPT_ENCODING] ||= SUPPORTED_ENCODINGS
        @app.call(env).on_complete do |response_env|
          case response_env[:response_headers][CONTENT_ENCODING]
          when 'gzip'
            reset_body(response_env, &method(:uncompress_gzip))
          when 'deflate'
            reset_body(response_env, &method(:inflate))
          end
        end
      end

      def reset_body(env)
        env[:body] = yield(env[:body])
        env[:response_headers].delete(CONTENT_ENCODING)
        env[:response_headers][CONTENT_LENGTH] = env[:body].length
      end

      def uncompress_gzip(body)
        io = StringIO.new(body)
        gzip_reader = if RUBY_ENCODING
          Zlib::GzipReader.new(io, :encoding => 'ASCII-8BIT')
        else
          Zlib::GzipReader.new(io)
        end
        gzip_reader.read
      end

      def inflate(body)
        # Inflate as a DEFLATE (RFC 1950+RFC 1951) stream
        Zlib::Inflate.inflate(body)
      rescue Zlib::DataError
        # Fall back to inflating as a "raw" deflate stream which
        # Microsoft servers return
        inflate = Zlib::Inflate.new(-Zlib::MAX_WBITS)
        begin
          inflate.inflate(body)
        ensure
          inflate.close
        end
      end
    end
  end
end
