# frozen_string_literal: true

require 'webrick'
require 'webrick/httpproxy'
require 'webrick/https'

class HTTPServerMock
  def initialize
    @port = 60_000
    begin
      @server = create_server(@port)
    rescue Errno::EADDRINUSE
      @port += 1
      retry
    end
  end

  def create_server(port)
    WEBrick::HTTPServer.new(
      BindAddress: '127.0.0.1',
      Port: port,
      Logger: WEBrick::Log.new("/dev/null"),
      AccessLog: [],
    )
  end

  def start
    Thread.new { @server.start }
  end

  def stop
    @server.shutdown
  end

  def base_uri
    URI("http://127.0.0.1:#{@port}")
  end

  def setup_response(uri_path, &action)
    @server.mount_proc(uri_path, action)
  end
end

def mock_server(server = nil)
  server = HTTPServerMock.new if server.nil?
  begin
    server.start
    yield server
  ensure
    server.stop
  end
end
