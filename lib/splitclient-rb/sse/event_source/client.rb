# frozen_string_literal: false

require 'concurrent/atomics'
require 'socketry'
require 'uri'

module SplitIoClient
  module SSE
    module EventSource
      class Client
        DEFAULT_READ_TIMEOUT = 70
        KEEP_ALIVE_RESPONSE = "c\r\n:keepalive\n\n\r\n".freeze

        def initialize(config, read_timeout: DEFAULT_READ_TIMEOUT)
          @config = config
          @read_timeout = read_timeout
          @connected = Concurrent::AtomicBoolean.new(false)
          @socket = nil
          @back_off = BackOff.new(@config.streaming_reconnect_back_off_base)

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

        def close
          dispatch_disconnect
          @connected.make_false
          SplitIoClient::Helpers::ThreadHelper.stop(:connect_stream, @config)
          @socket&.close
        rescue StandardError => e
          @config.logger.error("SSEClient close Error: #{e.inspect}")
        end

        def start(url)
          @uri = URI(url)

          connect_thread
        rescue StandardError => e
          @config.logger.error("SSEClient start Error: #{e.inspect}")
        end

        def connected?
          @connected.value
        end

        private

        def connect_thread
          @config.threads[:connect_stream] = Thread.new do
            @config.logger.info('Starting connect_stream thread ...') if @config.debug_enabled
            connect_stream
          end
        end

        def connect_stream
          interval = @back_off.interval
          sleep(interval) if interval.positive?

          socket_write

          while @connected.value
            begin
              partial_data = @socket.readpartial(10_000, timeout: @read_timeout)

              raise 'eof exception' if partial_data == :eof
            rescue StandardError => e
              @config.logger.error(e.inspect) if @config.debug_enabled
              @connected.make_false
              @socket&.close
              @socket = nil
              connect_stream
            end

            process_data(partial_data)
          end
        end

        def socket_write
          @socket = socket_connect
          @socket.write(build_request(@uri))
          dispatch_connected
        rescue StandardError => e
          @config.logger.error("Error during connecting to #{@uri.host}. Error: #{e.inspect}")
          close
        end

        def socket_connect
          return Socketry::SSL::Socket.connect(@uri.host, @uri.port) if @uri.scheme.casecmp('https').zero?

          Socketry::TCP::Socket.connect(@uri.host, @uri.port)
        end

        def process_data(partial_data)
          unless partial_data.nil? || partial_data == KEEP_ALIVE_RESPONSE
            @config.logger.debug("Event partial data: #{partial_data}") if @config.debug_enabled
            buffer = read_partial_data(partial_data)
            parse_event(buffer)
          end
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

        def read_partial_data(data)
          buffer = ''
          buffer << data
          buffer.chomp!
          buffer.split("\n")
        end

        def parse_event(buffer)
          type = nil

          buffer.each do |d|
            splited_data = d.split(':')

            case splited_data[0]
            when 'event'
              type = splited_data[1].strip
            when 'data'
              data = parse_event_data(d, type)
              unless type.nil? || data[:data].nil?
                event = StreamData.new(type, data[:client_id], data[:data], data[:channel])
                dispatch_event(event)
              end
            end
          end
        rescue StandardError => e
          @config.logger.error("Error during parsing a event: #{e.inspect}")
        end

        def parse_event_data(data, type)
          event_data = JSON.parse(data.sub('data: ', ''))
          client_id = event_data['clientId']&.strip
          channel = event_data['channel']&.strip
          parsed_data = JSON.parse(event_data['data']) unless type == 'error'
          parsed_data = event_data if type == 'error'

          { client_id: client_id, channel: channel, data: parsed_data }
        end

        def dispatch_event(event)
          raise SSEClientException.new(event), 'Error event' if event.event_type == 'error'

          @config.logger.debug("Dispatching event: #{event.event_type}, #{event.channel}") if @config.debug_enabled
          @on[:event].call(event)
        rescue SSEClientException => e
          @config.logger.error("Event error: #{e.event.event_type}, #{e.event.data}")
          close
        end

        def dispatch_connected
          @connected.make_true
          @back_off.reset
          @config.logger.debug('Dispatching connected') if @config.debug_enabled
          @on[:connected].call
        end

        def dispatch_disconnect
          @config.logger.debug('Dispatching disconnect') if @config.debug_enabled
          @on[:disconnect].call
        end
      end
    end
  end
end
