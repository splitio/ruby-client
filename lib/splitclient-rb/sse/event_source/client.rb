# frozen_string_literal: true

require 'concurrent/atomics'
require 'socketry'
require 'uri'

module SSE
  module EventSource
    class Client
      DEFAULT_READ_TIMEOUT = 200

      def initialize(channels, key, config, read_timeout: DEFAULT_READ_TIMEOUT)
        @uri = URI("https://realtime.ably.io/event-stream?channels=#{channels}&v=1.1&key=#{key}")
        @config = config
        @read_timeout = read_timeout
        @connected = Concurrent::AtomicBoolean.new(false)
        @first_time = Concurrent::AtomicBoolean.new(true)
        @socket = nil

        @on = { event: ->(_) {}, error: ->(_) {} }

        yield self if block_given?

        Thread.new do
          connect_stream
        end
      end

      def on_event(&action)
        @on[:event] = action
      end

      def on_error(&action)
        @on[:error] = action
      end

      def close
        @socket&.close if @connected.make_false
        @socket = nil if @connected.make_false
      end

      def status
        return SSE::EventSource::Status.CONNECTED if @connected.value
        return SSE::EventSource::Status.CONNECTING if !@connected.value && @first_time.value

        SSE::EventSource::Status.DISCONNECTED
      end

      private

      def connect_stream
        @config.logger.info("Connecting to #{@uri.host}...")

        @socket = Socketry::SSL::Socket.connect(@uri.host, @uri.port)
        @socket.write(build_request(@uri))

        while @connected.value || @first_time.value
          begin
            partial_data = @socket.readpartial(1024, timeout: @read_timeout)
          rescue Socketry::TimeoutError
            @config.logger.error("Socket read time out in #{@read_timeout}")

            sleep(50)
            connect_stream
          rescue StandardError => e
            @config.logger.error("Error reading socket request: #{e.inspect}")
            partial_data = nil
          end

          proccess_data(partial_data)
        end
      end

      def proccess_data(partial_data)
        unless partial_data.nil?
          @config.logger.debug("Event partial data: #{partial_data}")
          data = read_partial_data(partial_data)

          if !@first_time.value
            event = event_parser(data)

            dispatch_event(event)
          else
            @first_time.make_false
            @connected.make_true
          end
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

      def event_parser(data)
        type = ''
        event_data = nil

        data.each do |d|
          if d.include? 'event: '
            type = d.sub('event: ', '')
          elsif d.include? 'data: '
            json_data = d.sub('data: ', '')
            event_data = JSON.parse(json_data)
          end
        end

        return nil if type == '' || event_data.nil?

        StreamData.new(event_data['id'],
                       type,
                       event_data['name'],
                       event_data['data'],
                       event_data['channel'])
      rescue StandardError => e
        dispatch_error(e.inspect)
      end

      def dispatch_event(event)
        @config.logger.debug("Dispatching event: #{event}") unless event.nil?
        @on[:event].call(event) unless event.nil?
      end

      def dispatch_error(error)
        @config.logger.debug("Dispatching event error: #{error}")
        @on[:error].call(error)
      end
    end
  end
end
