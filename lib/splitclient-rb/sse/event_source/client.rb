# frozen_string_literal: false

require 'socketry'
require 'uri'

module SplitIoClient
  module SSE
    module EventSource
      class Client
        DEFAULT_READ_TIMEOUT = 70
        CONNECT_TIMEOUT = 30_000
        KEEP_ALIVE_RESPONSE = "c\r\n:keepalive\n\n\r\n".freeze
        ERROR_EVENT_TYPE = 'error'.freeze

        def initialize(config, read_timeout: DEFAULT_READ_TIMEOUT)
          @config = config
          @read_timeout = read_timeout
          @connected = Concurrent::AtomicBoolean.new(false)
          @socket = nil
          @event_parser = SSE::EventSource::EventParser.new(config)
          @on = { event: ->(_) {}, connected: ->(_) {}, disconnect: ->(_) {} }

          yield self if block_given?
        end

        def on_event(&action)
          @on[:event] = action
        end

        def on_connected(&action)
          @on[:connected] = action
        end

        def on_disconnect(&action)
          @on[:disconnect] = action
        end

        def close(reconnect = false)
          dispatch_disconnect(reconnect)
          @connected.make_false
          SplitIoClient::Helpers::ThreadHelper.stop(:connect_stream, @config)
          @socket&.close
        rescue StandardError => e
          @config.logger.error("SSEClient close Error: #{e.inspect}")
        end

        def start(url)
          @uri = URI(url)
          latch = Concurrent::CountDownLatch.new(1)

          connect_thread(latch)

          return false unless latch.wait(CONNECT_TIMEOUT)

          connected?
        rescue StandardError => e
          @config.logger.error("SSEClient start Error: #{e.inspect}")
          connected?
        end

        def connected?
          @connected.value
        end

        private

        def connect_thread(latch)
          @config.threads[:connect_stream] = Thread.new do
            @config.logger.info('Starting connect_stream thread ...') if @config.debug_enabled
            connect_stream(latch)
          end
        end

        def connect_stream(latch)
          socket_write(latch)

          while @connected.value
            begin
              partial_data = @socket.readpartial(10_000, timeout: @read_timeout)

              raise 'eof exception' if partial_data == :eof
            rescue StandardError => e
              @config.logger.error(e.inspect) if @config.debug_enabled
              close(true) # close conexion & reconnect
              return
            end

            process_data(partial_data)
          end
        end

        def socket_write(latch)
          @socket = socket_connect
          @socket.write(build_request(@uri))
          dispatch_connected
        rescue StandardError => e
          @config.logger.error("Error during connecting to #{@uri.host}. Error: #{e.inspect}")
          close
        ensure
          latch.count_down
        end

        def socket_connect
          return Socketry::SSL::Socket.connect(@uri.host, @uri.port) if @uri.scheme.casecmp('https').zero?

          Socketry::TCP::Socket.connect(@uri.host, @uri.port)
        end

        def process_data(partial_data)
          return if partial_data.nil? || partial_data == KEEP_ALIVE_RESPONSE

          @config.logger.debug("Event partial data: #{partial_data}") if @config.debug_enabled
          events = @event_parser.parse(partial_data)
          events.each { |event| process_event(event) }
        rescue StandardError => e
          @config.logger.error("process_data error: #{e.inspect}")
        end

        def build_request(uri)
          req = "GET #{uri.request_uri} HTTP/1.1\r\n"
          req << "Host: #{uri.host}\r\n"
          req << "Accept: text/event-stream\r\n"
          req << "Cache-Control: no-cache\r\n\r\n"
          @config.logger.debug("Request info: #{req}") if @config.debug_enabled
          req
        end

        def process_event(event)
          case event.event_type
          when ERROR_EVENT_TYPE
            dispatch_error(event)
          else
            dispatch_event(event)
          end
        end

        def dispatch_error(event)
          @config.logger.error("Event error: #{event.event_type}, #{event.data}")
          if event.data['code'] >= 40_140 && event.data['code'] <= 40_149
            close(true) # close conexion & reconnect
          elsif event.data['code'] >= 40_000 && event.data['code'] <= 49_999
            close # close conexion
          end
        end

        def dispatch_event(event)
          @config.logger.debug("Dispatching event: #{event.event_type}, #{event.channel}") if @config.debug_enabled
          @on[:event].call(event)
        end

        def dispatch_connected
          @connected.make_true
          @config.logger.debug('Dispatching connected') if @config.debug_enabled
          @on[:connected].call
        end

        def dispatch_disconnect(reconnect)
          @config.logger.debug('Dispatching disconnect') if @config.debug_enabled
          @on[:disconnect].call(reconnect)
        end
      end
    end
  end
end
