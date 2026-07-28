# frozen_string_literal: true

#
# Split Ruby SDK - Local Mock Server Example
#
# Stands up a local WEBrick server that mocks every endpoint the SDK talks to
# (auth, splitChanges, segmentChanges, events, telemetry, and the SSE stream),
# then boots the SDK against it. This lets us deterministically reproduce
# streaming edge cases WITHOUT a real backend.
#
# The SSE endpoint behaviour is driven by the SSE_MODE env var:
#
#   SSE_MODE=ok        -> normal 200 stream, sends a keepalive then stays open (default)
#   SSE_MODE=eof       -> 200, sends the OK first-event, then closes the socket (clean EOF)
#   SSE_MODE=400       -> responds to the stream request with HTTP 400
#   SSE_MODE=401       -> responds to the stream request with HTTP 401
#   SSE_MODE=500       -> responds to the stream request with HTTP 500
#   SSE_MODE=scenario  -> connect -> SPLIT_UPDATE -> Ably error event -> expects a
#                         reconnect. Each /sse hit is logged with its attempt number
#                         so you can see the second connection land.
#   SSE_MODE=graceful_shutdown -> connect -> SPLIT_UPDATE -> server closes the TCP
#                         connection cleanly (no error event, no 4xx/5xx — just a
#                         FIN), same as an LB/server recycling a healthy connection.
#                         Expects the SDK to hit EOFError and reconnect.
#   SSE_MODE=ungraceful -> connect -> SPLIT_UPDATE -> the stream is cut abruptly
#                         (simulated pod crash), and the NEXT couple of reconnect
#                         attempts get 504 Gateway Timeout / 500 Internal Server
#                         Error (simulating the pod restarting / gateway with no
#                         healthy backend yet). Expects the SDK to keep retrying
#                         with backoff and eventually reconnect once the "pod" is
#                         back (4th attempt).
#   AUTH_MODE=401      -> make the AUTH service return 401 (before SSE is ever attempted)
#
# Usage:
#   SSE_MODE=401               ruby spec/sse_debug_server.rb
#   AUTH_MODE=401               ruby spec/sse_debug_server.rb
#   SSE_MODE=scenario           ruby spec/sse_debug_server.rb
#   SSE_MODE=graceful_shutdown  ruby spec/sse_debug_server.rb
#   SSE_MODE=ungraceful         ruby spec/sse_debug_server.rb
#

# Load the local library code (this repo) instead of an installed gem.
$LOAD_PATH.unshift(File.expand_path('../lib', __dir__))

require 'splitclient-rb'
require 'webrick'
require 'json'

SSE_MODE  = ENV.fetch('SSE_MODE', 'ok')
AUTH_MODE = ENV.fetch('AUTH_MODE', 'ok')
PORT      = Integer(ENV.fetch('PORT', '8123'))

# A valid-looking Ably token + channels payload. The token is only parsed for
# channels/exp; its signature is never verified by the SDK.
AUTH_BODY = {
  pushEnabled: true,
  token: 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJ4LWFibHktY2FwYWJpbGl0eSI6IntcInh4eHhfeHh4eF9zZWdtZW50c1wiOltcInN1YnNjcmliZVwiXSxcInh4eHhfeHh4eF9zcGxpdHNcIjpbXCJzdWJzY3JpYmVcIl0sXCJjb250cm9sX3ByaVwiOltcInN1YnNjcmliZVwiLFwiY2hhbm5lbC1tZXRhZGF0YTpwdWJsaXNoZXJzXCJdLFwiY29udHJvbF9zZWNcIjpbXCJzdWJzY3JpYmVcIixcImNoYW5uZWwtbWV0YWRhdGE6cHVibGlzaGVyc1wiXX0iLCJ4LWFibHktY2xpZW50SWQiOiJjbGllbnRJZCIsImV4cCI6MTk4OTgyMTc1NSwiaWF0IjoxNTg5ODE4MTU1fQ'
}.freeze

EMPTY_SPLITS = { ff: { d: [], s: -1, t: 4_000_000 }, rbs: { d: [], s: -1, t: 4_000_000 } }.freeze

# Base64 (no compression) encoded split definition used by SSE_MODE=scenario's
# SPLIT_UPDATE event.
SCENARIO_CHANGE_NUMBER = 4_000_000
SCENARIO_SPLIT_B64 = 'eyJ0cmFmZmljVHlwZU5hbWUiOiJ1c2VyIiwibmFtZSI6Im1vY2tfc2NlbmFyaW9fZmxhZyIsInRyYWZmaWNBbGxvY2F0aW9uIjoxMDAsInRyYWZmaWNBbGxvY2F0aW9uU2VlZCI6MSwic2VlZCI6MSwic3RhdHVzIjoiQUNUSVZFIiwia2lsbGVkIjpmYWxzZSwiZGVmYXVsdFRyZWF0bWVudCI6Im9mZiIsImNoYW5nZU51bWJlciI6MTcwMDAwMDAwMDAwMCwiYWxnbyI6MiwiY29uZmlndXJhdGlvbnMiOnt9LCJjb25kaXRpb25zIjpbeyJjb25kaXRpb25UeXBlIjoiUk9MTE9VVCIsIm1hdGNoZXJHcm91cCI6eyJjb21iaW5lciI6IkFORCIsIm1hdGNoZXJzIjpbeyJtYXRjaGVyVHlwZSI6IkFMTF9LRVlTIiwibmVnYXRlIjpmYWxzZX1dfSwicGFydGl0aW9ucyI6W3sidHJlYXRtZW50Ijoib24iLCJzaXplIjoxMDB9LHsidHJlYXRtZW50Ijoib2ZmIiwic2l6ZSI6MH1dLCJsYWJlbCI6ImRlZmF1bHQgcnVsZSJ9XX0='

def scenario_split_update_event
  data = {
    type: 'SPLIT_UPDATE',
    changeNumber: SCENARIO_CHANGE_NUMBER,
    pcn: -1,
    c: 0,
    d: SCENARIO_SPLIT_B64
  }.to_json
  payload = {
    id: '1', clientId: 'mockClientId', timestamp: Time.now.to_i, encoding: 'json',
    channel: 'mock_channel', data: data, name: 'message'
  }.to_json
  content = "id: 1\nevent: message\ndata: #{payload}\n\n"
  "#{content.bytesize.to_s(16)}\r\n#{content}\r\n"
end

def control_pri_occupancy_event(publishers: 2)
  data = { metrics: { publishers: publishers } }.to_json
  payload = {
    id: '1', timestamp: Time.now.to_i, encoding: 'json',
    channel: '[?occupancy=metrics.publishers]control_pri', data: data, name: '[meta]occupancy'
  }.to_json
  content = "event: message\ndata: #{payload}\n\n"
  "#{content.bytesize.to_s(16)}\r\n#{content}\r\n"
end

def scenario_error_event
  # code 40142 falls in Ably's 40140-40149 "reconnect" range (see
  # Client#dispatch_error), so the SDK treats this as PUSH_RETRYABLE_ERROR.
  payload = { message: 'Token expired', code: 40_142, statusCode: 401, href: 'https://help.ably.io/error/40142' }.to_json
  content = "event: error\ndata: #{payload}\n\n"
  "#{content.bytesize.to_s(16)}\r\n#{content}\r\n"
end

$sse_attempt = 0

server = WEBrick::HTTPServer.new(
  BindAddress: '127.0.0.1',
  Port: PORT,
  Logger: WEBrick::Log.new($stdout, WEBrick::Log::INFO),
  AccessLog: []
)

# --- Auth service -----------------------------------------------------------
server.mount_proc('/api/v2/auth') do |_req, res|
  if AUTH_MODE == '401'
    res.status = 401
    res.body = ''
    puts '>> AUTH: responding 401'
  else
    res.status = 200
    res.content_type = 'application/json'
    res.body = AUTH_BODY.to_json
    puts '>> AUTH: responding 200 (pushEnabled=true)'
  end
end

# --- SDK splitChanges / segmentChanges (polling fallback) -------------------
server.mount_proc('/api/splitChanges') do |_req, res|
  res.status = 200
  res.content_type = 'application/json'
  res.body = EMPTY_SPLITS.to_json
end

server.mount_proc('/api/segmentChanges') do |_req, res|
  res.status = 200
  res.content_type = 'application/json'
  res.body = { name: 'seg', added: [], removed: [], since: -1, till: -1 }.to_json
end

# --- Events / Telemetry (fire-and-forget) -----------------------------------
%w[/api/events/bulk /api/testImpressions/bulk /api/testImpressions/count
   /api/keys/ss /api/metrics/usage /api/metrics/config /api/v1/metrics/usage
   /api/v1/metrics/config /api/v1/keys/ss].each do |path|
  server.mount_proc(path) do |_req, res|
    res.status = 200
    res.body = 'ok'
  end
end

# --- SSE stream -------------------------------------------------------------
server.mount_proc('/sse') do |_req, res|
  $sse_attempt += 1
  attempt = $sse_attempt
  puts ">> SSE: connection attempt ##{attempt}"

  case SSE_MODE
  when 'scenario'
    res.status = 200
    res.content_type = 'text/event-stream'
    res.keep_alive = false
    res['Connection'] = 'close'
    res.chunked = true
    rd, wr = IO.pipe
    res.body = rd

    Thread.new do
      # 1. First event establishes the connection (first_event code check == 200)
      #    and reports 2 publishers available on control_pri, same as a real
      #    Ably occupancy notification.
      wr.write(control_pri_occupancy_event(publishers: 2))
      sleep 0.3

      if attempt == 1
        # 2. Deliver a SPLIT_UPDATE the SDK should process successfully.
        puts '>> SSE: sending SPLIT_UPDATE'
        wr.write(scenario_split_update_event)
        sleep 0.3

        # 3. Simulate a server-side error event -> the client should close and
        #    the SyncManager should reconnect (PUSH_RETRYABLE_ERROR).
        puts '>> SSE: sending error event (simulated server error)'
        wr.write(scenario_error_event)
        sleep 0.3
      else
        puts ">> SSE: attempt ##{attempt} reconnected successfully, staying up"
        loop do
          sleep 20
          begin
            wr.write("c\r\n:keepalive\n\n\r\n")
          rescue StandardError
            break
          end
        end
      end
    ensure
      begin
        wr.close
      rescue StandardError
        nil
      end
    end
  when 'graceful_shutdown'
    res.status = 200
    res.content_type = 'text/event-stream'
    res.keep_alive = false
    res['Connection'] = 'close'
    res.chunked = true
    rd, wr = IO.pipe
    res.body = rd

    Thread.new do
      # 1. First event establishes the connection.
      wr.write(control_pri_occupancy_event(publishers: 2))
      sleep 0.3

      if attempt == 1
        # 2. Deliver a SPLIT_UPDATE the SDK should process successfully.
        puts '>> SSE: sending SPLIT_UPDATE'
        wr.write(scenario_split_update_event)
        sleep 0.3

        # 3. Close the connection cleanly (FIN, no error event) -- simulates the
        #    server/LB gracefully shutting down a healthy connection. The client's
        #    readpartial should hit EOFError and the SDK should reconnect.
        puts ">> SSE: attempt ##{attempt} gracefully closing the connection (no error event)"
      else
        # 4. On reconnect, stay up so we can confirm the SDK settles into a
        #    stable connected state instead of looping forever.
        puts ">> SSE: attempt ##{attempt} reconnected successfully, staying up"
        loop do
          sleep 20
          begin
            wr.write("c\r\n:keepalive\n\n\r\n")
          rescue StandardError
            break
          end
        end
      end
    ensure
      begin
        wr.close
      rescue StandardError
        nil
      end
    end
  when 'ungraceful'
    # Attempt 1: connect normally and process an update, then the "pod" crashes
    # (the TCP connection is torn down abruptly, no clean FIN/close). Attempts
    # 2-3: the gateway/LB has no healthy backend yet and answers with 504/500,
    # same as a Kubernetes readiness gap after a pod restart. Attempt 4+: the
    # backend is back, respond normally and stay connected.
    if attempt == 1
      res.status = 200
      res.content_type = 'text/event-stream'
      res.chunked = true
      rd, wr = IO.pipe
      res.body = rd

      Thread.new do
        wr.write(control_pri_occupancy_event(publishers: 2))
        sleep 0.3

        puts '>> SSE: sending SPLIT_UPDATE'
        wr.write(scenario_split_update_event)
        sleep 0.3

        puts ">> SSE: attempt ##{attempt} simulating pod crash (abrupt socket close, no FIN)"
        # Closing only the write end without flushing/finishing the chunked
        # response leaves the client mid-read with no clean EOF marker --
        # closer to a killed pod than a graceful shutdown.
        wr.close
      end
    elsif attempt.between?(2, 3)
      status = attempt == 2 ? 504 : 500
      res.status = status
      res.content_type = 'text/event-stream'
      res.body = ''
      puts ">> SSE: attempt ##{attempt} responding HTTP #{status} (gateway/backend still recovering)"
    else
      res.status = 200
      res.content_type = 'text/event-stream'
      res.chunked = true
      rd, wr = IO.pipe
      res.body = rd
      wr.write(control_pri_occupancy_event(publishers: 2))

      Thread.new do
        puts ">> SSE: attempt ##{attempt} reconnected successfully, staying up"
        loop do
          sleep 20
          begin
            wr.write("c\r\n:keepalive\n\n\r\n")
          rescue StandardError
            break
          end
        end
      end
    end
  when '400', '401', '500'
    res.status = Integer(SSE_MODE)
    res.content_type = 'text/event-stream'
    res.body = ''
    puts ">> SSE: responding HTTP #{SSE_MODE}"
  when 'eof'
    # Send the OK first event so the client marks itself connected, then close
    # the TCP connection -> the client's readpartial hits EOFError.
    # Connection: close disables keep-alive so WEBrick actually FINs the socket
    # once the body pipe drains.
    res.status = 200
    res.content_type = 'text/event-stream'
    res.keep_alive = false
    res['Connection'] = 'close'
    res.chunked = true
    rd, wr = IO.pipe
    wr.write(control_pri_occupancy_event(publishers: 2))
    wr.close
    res.body = rd
    puts '>> SSE: responding 200 then closing (EOF)'
  else # 'ok'
    res.status = 200
    res.content_type = 'text/event-stream'
    res.chunked = true
    rd, wr = IO.pipe
    wr.write("c\r\n:keepalive\n\n\r\n")
    # Keep the pipe open so the connection stays alive.
    Thread.new do
      loop do
        sleep 20
        begin
          wr.write("c\r\n:keepalive\n\n\r\n")
        rescue StandardError
          break
        end
      end
    end
    res.body = rd
    puts '>> SSE: responding 200, streaming keepalives'
  end
end

Thread.new { server.start }
sleep 0.5

puts "Mock server on http://127.0.0.1:#{PORT}  (SSE_MODE=#{SSE_MODE}, AUTH_MODE=#{AUTH_MODE})"

base = "http://127.0.0.1:#{PORT}"
options = {
  base_uri: "#{base}/api",
  events_uri: "#{base}/api",
  streaming_service_url: "#{base}/sse",
  auth_service_url: "#{base}/api/v2/auth",
  telemetry_service_url: "#{base}/api/v1",
  streaming_enabled: true,
  debug_enabled: true
}

factory = SplitIoClient::SplitFactory.new('localhost-mock-key', options)
client = factory.client

begin
  client.block_until_ready(10)
  puts 'SDK is ready!'
rescue SplitIoClient::SDKBlockerTimeoutExpiredException
  puts 'SDK timed out waiting to be ready.'
end

# Keep running so we can watch the streaming lifecycle in the logs.
loop { sleep 3 }
