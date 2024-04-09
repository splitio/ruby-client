# frozen_string_literal: false

require 'socketry'
require 'uri'

module SplitIoClient
  module SSE
    module EventSource
      class Client
        DEFAULT_READ_TIMEOUT = 70
        CONNECT_TIMEOUT = 30_000
        OK_CODE = 200
        KEEP_ALIVE_RESPONSE = "c\r\n:keepalive\n\n\r\n".freeze
        ERROR_EVENT_TYPE = 'error'.freeze

        def initialize(config,
                       api_key,
                       telemetry_runtime_producer,
                       event_parser,
                       notification_manager_keeper,
                       notification_processor,
                       status_queue,
                       request_decorator,
                       read_timeout: DEFAULT_READ_TIMEOUT)
          @config = config
          @api_key = api_key
          @telemetry_runtime_producer = telemetry_runtime_producer
          @event_parser = event_parser
          @notification_manager_keeper = notification_manager_keeper
          @notification_processor = notification_processor
          @status_queue = status_queue
          @read_timeout = read_timeout
          @connected = Concurrent::AtomicBoolean.new(false)
          @first_event = Concurrent::AtomicBoolean.new(true)
          @socket = nil
          @request_decorator = request_decorator
        end

        def close(status = nil)
          unless connected?
            @config.logger.error('SSEClient already disconected.') if @config.debug_enabled
            return
          end

          @connected.make_false
          @socket&.close
          push_status(status)
        rescue StandardError => e
          @config.logger.error("SSEClient close Error: #{e.inspect}")
        end

        def start(url)
          if connected?
            @config.logger.debug('SSEClient already running.')
            return true
          end

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
            new_status = connect_stream(latch)
            push_status(new_status)
            @config.logger.info('connect_stream thread finished.') if @config.debug_enabled
          end
        end

        def connect_stream(latch)
          return Constants::PUSH_NONRETRYABLE_ERROR unless socket_write(latch)

          while connected? || @first_event.value
            begin
              partial_data = @socket.readpartial(10_000, timeout: @read_timeout)

              read_first_event(partial_data, latch)

              raise 'eof exception' if partial_data == :eof
            rescue Errno::EBADF, IOError => e
              @config.logger.error(e.inspect) if @config.debug_enabled
              return nil
            rescue StandardError => e
              return nil if ENV['SPLITCLIENT_ENV'] == 'test'

              @config.logger.error("Error reading partial data: #{e.inspect}") if @config.debug_enabled
              return Constants::PUSH_RETRYABLE_ERROR
            end

            process_data(partial_data)
          end
          nil
        end

        def socket_write(latch)
          @first_event.make_true
          @socket = socket_connect
          @socket.write(build_request(@uri))
          true
        rescue StandardError => e
          @config.logger.error("Error during connecting to #{@uri.host}. Error: #{e.inspect}")
          latch.count_down
          false
        end

        def read_first_event(data, latch)
          return unless @first_event.value

          response_code = @event_parser.first_event(data)
          @config.logger.debug("SSE client first event code: #{response_code}")

          error_event = false
          events = @event_parser.parse(data)
          events.each { |e| error_event = true if e.event_type == ERROR_EVENT_TYPE }
          @first_event.make_false

          if response_code == OK_CODE && !error_event
            @connected.make_true
            @telemetry_runtime_producer.record_streaming_event(Telemetry::Domain::Constants::SSE_CONNECTION_ESTABLISHED, nil)
            push_status(Constants::PUSH_CONNECTED)
          end

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
          custom_headers = @request_decorator.decorate_headers({})

          req = "GET #{uri.request_uri} HTTP/1.1\r\n"
          req << "Host: #{uri.host}\r\n"
          req << "Accept: text/event-stream\r\n"
          req << "SplitSDKVersion: #{@config.language}-#{@config.version}\r\n"
          req << "SplitSDKMachineIP: #{@config.machine_ip}\r\n"
          req << "SplitSDKMachineName: #{@config.machine_name}\r\n"
          req << "SplitSDKClientKey: #{@api_key.split(//).last(4).join}\r\n" unless @api_key.nil?
          custom_headers.keys().each{ |header| req << header + ": " + custom_headers[header] + "\r\n" }
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
          @telemetry_runtime_producer.record_streaming_event(Telemetry::Domain::Constants::ABLY_ERROR, event.data['code'])

          if event.data['code'] >= 40_140 && event.data['code'] <= 40_149
            close(Constants::PUSH_RETRYABLE_ERROR)
          elsif event.data['code'] >= 40_000 && event.data['code'] <= 49_999
            close(Constants::PUSH_NONRETRYABLE_ERROR)
          end
        end

        def dispatch_event(event)
          if event.occupancy?
            @notification_manager_keeper.handle_incoming_occupancy_event(event)
          else
            @notification_processor.process(event)
          end
        end

        def push_status(status)
          return if status.nil?

          @config.logger.debug("Pushing new sse status: #{status}")
          @status_queue.push(status)
        end
      end
    end
  end
end
