desc "Benchmark the get_treatment method call in 4 threads"

# Usage:
# rake concurrent_benchmark api_key=YOUR_API_KEY base_uri=YOUR_API_BASE_URI [iterations=NUMBER_OF_ITERATIONS] [user_id=A_USER_ID] [feature_id=A_FEATURE_ID]
task :concurrent_benchmark do
  require 'benchmark'
  require 'splitclient-rb'

  usage_message = "Usage: rake concurrent_benchmark api_key=YOUR_API_KEY base_uri=YOUR_API_BASE_URI [iterations=NUMBER_OF_ITERATIONS] [user_id=A_USER_ID] [feature_id=A_FEATURE_ID]"
  valid_params = validate_params
  if validate_params
    execute
  else
    p usage_message
  end
end

def validate_params
  !ENV['api_key'].nil? && !ENV['base_uri'].nil?
end

def execute
  api_key = ENV['api_key'].nil? ? "fake_api_key" : ENV['api_key']
  base_uri = ENV['base_uri'].nil? ? "fake/api/" : ENV['base_uri']
  iterations = ENV['iterations'].nil? ? 1000000 : ENV['iterations'].to_i
  user_id = ENV['user_id'].nil? ? "fake_id_1" : ENV['user_id']
  feature_id = ENV['feature_id'].nil? ? "sample_feature" : ENV['feature_id']

  threads = []
  times_per_thread = iterations / 4
  split_client = SplitIoClient::SplitFactory.new(api_key, {base_uri: base_uri, logger: Logger.new("/dev/null") })

  puts Benchmark.measure{
    4.times do |i|
      threads << Thread.new do
        times_per_thread.times do
          split_client.get_treatment user_id, feature_id, {attr: 123}
        end
      end
    end
    threads.map(&:join)
  }
end
