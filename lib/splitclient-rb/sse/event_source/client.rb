# frozen_string_literal: false

require 'concurrent/atomics'
require 'socketry'
require 'uri'

module SplitIoClient
  module SSE
    module EventSource
      class Client
        DEFAULT_READ_TIMEOUT = 200
        KEEP_ALIVE_RESPONSE = "c\r\n:keepalive\n\n\r\n".freeze

        def initialize(url, config, read_timeout: DEFAULT_READ_TIMEOUT)
          @uri = URI(url)
          @config = config
          @read_timeout = read_timeout
          @connected = Concurrent::AtomicBoolean.new(false)
          @socket = nil

          @on = { event: ->(_) {}, error: ->(_) {} }

          yield self if block_given?

          connect_thread

          connect_passenger_forked if defined?(PhusionPassenger)
        end

        def on_event(&action)
          @on[:event] = action
        end

        def on_error(&action)
          @on[:error] = action
        end

        def close
          @connected.make_false
          @socket&.close
          @socket = nil
        end

        def status
          return Status::CONNECTED if @connected.value

          Status::DISCONNECTED
        end

        private

        def connect_thread
          @config.threads[:connect_stream] = Thread.new do
            connect_stream
          end
        end

        def connect_passenger_forked
          PhusionPassenger.on_event(:starting_worker_process) { |forked| connect_thread if forked }
        end

        def connect_stream
          @config.logger.info("Connecting to #{@uri.host}...")

          begin
            @socket = socket_connect

            @socket.write(build_request(@uri))
            @connected.make_true
          rescue StandardError => e
            dispatch_error(e.inspect)
          end

          while @connected.value
            begin
              partial_data = @socket.readpartial(2048, timeout: @read_timeout)
            rescue Socketry::TimeoutError
              @config.logger.error("Socket read time out in #{@read_timeout}")
              @connected.make_false
              connect_stream
            end

            proccess_data(partial_data) unless partial_data == KEEP_ALIVE_RESPONSE
          end
        end

        def socket_connect
          return Socketry::SSL::Socket.connect(@uri.host, @uri.port) if @uri.scheme.casecmp('https').zero?

          Socketry::TCP::Socket.connect(@uri.host, @uri.port)
        end

        def proccess_data(partial_data)
          unless partial_data.nil?
            @config.logger.debug("Event partial data: #{partial_data}")
            buffer = read_partial_data(partial_data)
            event = parse_event(buffer)

            dispatch_event(event)
          end
        rescue StandardError => e
          dispatch_error(e.inspect)
        end

        def build_request(uri)
          req = "GET #{uri.request_uri} HTTP/1.1\r\n"
          req << "Host: #{uri.host}\r\n"
          req << "Accept: text/event-stream\r\n"
          req << "Cache-Control: no-cache\r\n"
          req << "\r\n"
          @config.logger.debug("Request info: #{req}")
          req
        end

        def read_partial_data(data)
          buffer = ''
          buffer << data
          buffer.chomp!
          buffer.split("\n")
        end

        def parse_event(buffer)
          event_type = nil
          parsed_data = nil
          client_id = nil

          buffer.each do |d|
            splited_data = d.split(':')

            case splited_data[0]
            when 'event'
              event_type = splited_data[1].strip
            when 'data'
              event_data = JSON.parse(d.sub('data: ', ''))
              client_id = event_data['clientId']&.strip
              parsed_data = JSON.parse(event_data['data'])
            end
          end

          return StreamData.new(event_type, client_id, parsed_data) unless event_type.nil? || parsed_data.nil?

          raise 'Invalid event format.'
        rescue StandardError => e
          dispatch_error(e.inspect)
          nil
        end

        def dispatch_event(event)
          @config.logger.debug("Dispatching event: #{event}") unless event.nil?
          @on[:event].call(event) unless event.nil?
        end

        def dispatch_error(error)
          @config.logger.debug("Dispatching error: #{error}")
          @on[:error].call(error)
        end
      end

      StreamData = Struct.new(:event_type, :client_id, :data)
    end
  end
end
