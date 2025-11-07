# frozen_string_literal: false

require 'socket'
require 'openssl'
require 'uri'
require 'timeout'

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
        end

        def close(status = nil)
          unless connected?
            log_if_debug('SSEClient already disconected.', 3)
            return
          end

          @connected.make_false
          @socket.close
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
            log_if_debug('Starting connect_stream thread ...', 2)
            new_status = connect_stream(latch)
            push_status(new_status)
            log_if_debug('connect_stream thread finished.', 2)
          end
        end

        def connect_stream(latch)
          return Constants::PUSH_NONRETRYABLE_ERROR unless socket_write(latch)
          while connected? || @first_event.value
            log_if_debug("Inside coonnect_stream while loop.", 3)
            if IO.select([@socket], nil, nil, @read_timeout)
              begin
                partial_data = @socket.readpartial(10_000)
                read_first_event(partial_data, latch)

                raise 'eof exception' if partial_data == :eof
              rescue IO::WaitReadable => e
                log_if_debug("SSE client transient error: #{e.inspect}", 1)
                IO.select([@socket], nil, nil, @read_timeout)
                retry
              rescue Errno::ETIMEDOUT => e
                log_if_debug("SSE read operation timed out!: #{e.inspect}", 3)
                return Constants::PUSH_RETRYABLE_ERROR
              rescue EOFError => e
                log_if_debug("SSE read operation EOF Exception!: #{e.inspect}", 3)
                raise 'eof exception'
              rescue  Errno::EAGAIN => e
                log_if_debug("SSE client transient error: #{e.inspect}", 1)
                IO.select([@socket], nil, nil, @read_timeout)
                retry
              rescue Errno::EBADF, IOError => e
                log_if_debug("SSE read operation EBADF or IOError: #{e.inspect}", 3)
                return nil
              rescue StandardError => e
                log_if_debug("SSE read operation StandardError: #{e.inspect}", 3)
                return nil if ENV['SPLITCLIENT_ENV'] == 'test'

                log_if_debug("Error reading partial data: #{e.inspect}", 3)
                return Constants::PUSH_RETRYABLE_ERROR
              end
            else
              # Timeout occurred, no data available
              log_if_debug("SSE read operation timed out, no data available.", 3)
              return Constants::PUSH_RETRYABLE_ERROR
            end

            process_data(partial_data)
          end
          log_if_debug("SSE read operation exited: #{connected?}", 3)

          nil
        end

        def socket_write(latch)
          @first_event.make_true
          @socket = socket_connect
          @socket.puts(build_request(@uri))
          true
        rescue StandardError => e
          log_if_debug("Error during connecting to #{@uri.host}. Error: #{e.inspect}", 3)
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
            @config.logger.debug("SSE client first event Connected is true")
            @telemetry_runtime_producer.record_streaming_event(Telemetry::Domain::Constants::SSE_CONNECTION_ESTABLISHED, nil)
            push_status(Constants::PUSH_CONNECTED)
          end

          latch.count_down
        end

        def socket_connect
          tcp_socket = TCPSocket.new(@uri.host, @uri.port)
          if @uri.scheme.casecmp('https').zero?
            begin
              ssl_context = OpenSSL::SSL::SSLContext.new
              ssl_socket = OpenSSL::SSL::SSLSocket.new(tcp_socket, ssl_context)
              ssl_socket.hostname = @uri.host

              begin
                ssl_socket.connect_nonblock
              rescue IO::WaitReadable
                IO.select([ssl_socket])
                retry
              rescue IO::WaitWritable
                IO.select(nil, [ssl_socket])
                retry
              end

              return ssl_socket
#              return ssl_socket.connect 
            rescue Exception => e
              @config.logger.error("socket connect error: #{e.inspect}")
              return nil
            end
          end

          tcp_socket
        end

        def process_data(partial_data)
          log_if_debug("Event partial data: #{partial_data}", 1)
          return if partial_data.nil? || partial_data == KEEP_ALIVE_RESPONSE

          events = @event_parser.parse(partial_data)
          events.each { |event| process_event(event) }
        rescue StandardError => e
          @config.logger.error("process_data error: #{e.inspect}")
        end

        def build_request(uri)
          req = "GET #{uri.request_uri} HTTP/1.1\r\n"
          req << "Host: #{uri.host}\r\n"
          req << "Accept: text/event-stream\r\n"
          req << "SplitSDKVersion: #{@config.language}-#{@config.version}\r\n"
          req << "SplitSDKMachineIP: #{@config.machine_ip}\r\n"
          req << "SplitSDKMachineName: #{@config.machine_name}\r\n"
          req << "SplitSDKClientKey: #{@api_key.split(//).last(4).join}\r\n" unless @api_key.nil?
          req << "Cache-Control: no-cache\r\n\r\n"
          log_if_debug("Request info: #{req}", 1)
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

        def log_if_debug(text, level)
          if @config.debug_enabled
            case level
            when 1
              @config.logger.debug(text)
            when 2
              @config.logger.info(text)
            else
              @config.logger.error(text)
            end
          end
        end
      end
    end
  end
end
