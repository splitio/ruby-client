desc "Benchmark the is_treatment? method call"

# Usage:
# rake benchmark api_key=YOUR_API_KEY base_uri=YOUR_API_BASE_URI user_id=A_USER_ID segment_id=A_SEGMENT_ID default_treatment=A_DEFAULT_TREATMENT
task :benchmark do
  require 'benchmark'
  require 'splitclient-rb'
  p "Usage: rake benchmark [iterations=NUMBER_OF_ITERATIONS] [api_key=YOUR_API_KEY] [base_uri=YOUR_API_BASE_URI]
  [user_id=A_USER_ID] [segment_id=A_SEGMENT_ID][ default_treatment=A_DEFAULT_TREATMENT]"

  iterations = ENV['iterations'].nil? ? 1000000 : ENV['iterations'].to_i
  api_key = ENV['api_key'].nil? ? "7srsoj1bgcs5hh2uitmldnimdgpd6atkn405" : ENV['api_key']
  base_uri = ENV['base_uri'].nil? ? "http://localhost:8081/api/" : ENV['base_uri']
  user_id = ENV['user_id'].nil? ? "user_1" : ENV['user_id']
  segment_id = ENV['segment_id'].nil? ? "test_all" : ENV['segment_id']
  default_treatment = ENV['default_treatment'].nil? ? "on" : ENV['default_treatment']

  split_client = SplitIoClient::SplitClient.new(api_key, {base_uri: base_uri, logger: Logger.new("/dev/null")})
  Benchmark.bm do |bm|
    bm.report do
      iterations.times do
        Benchmark.measure { split_client.is_treatment? user_id, segment_id, default_treatment }
      end
    end
  end
end
