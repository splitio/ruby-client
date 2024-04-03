# frozen_string_literal: true

module SplitIoClient
  module Api
    class RequestDecorator
      FORBIDDEN_HEADERS = [
        "SplitSDKVersion",
        "SplitMachineIp",
        "SplitMachineName",
        "SplitImpressionsMode",
        "Host",
        "Referrer",
        "Content-Type",
        "Content-Length",
        "Content-Encoding",
        "Accept",
        "Keep-Alive",
        "X-Fastly-Debug"
      ]

      def initialize(custom_header_decorator)
        @custom_header_decorator = custom_header_decorator
        if @custom_header_decorator.nil?
          @custom_header_decorator = SplitIoClient::Api::NoOpHeaderDecorator.new
        end
      end

      def decorate_headers(request)
        custom_headers = @custom_header_decorator.get_header_overrides(SplitIoClient::Api::RequestContext.new(request.headers.clone))
        custom_headers.keys().each do |header|
          if is_header_allowed(header)
            if request.headers[header].is_a?(Array)
              request.headers[header] = custom_headers[header].join(',')
            else
              request.headers[header] = custom_headers[header]
            end
          end
        end
        request
      rescue StandardError => e
        raise e, 'Problem adding custom header in request decorator', e.backtrace
      end

      private

      def is_header_allowed(header)
        return !FORBIDDEN_HEADERS.map { |forbidden| forbidden.downcase }.include?(header.downcase)
      end
    end
  end
end
