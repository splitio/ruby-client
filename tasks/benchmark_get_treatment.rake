# frozen_string_literal: true

desc 'Benchmark the get_treatment method call in 4 threads'

# Usage:
# rake concurrent_benchmark api_key=YOUR_API_KEY base_uri=YOUR_API_BASE_URI
# [iterations=NUMBER_OF_ITERATIONS] [user_id=A_USER_ID] [feature_id=A_FEATURE_ID]
task :concurrent_benchmark do
  require 'benchmark'
  require 'splitclient-rb'

  usage_message = 'Usage: rake concurrent_benchmark api_key=YOUR_API_KEY base_uri=YOUR_API_BASE_URI \
  [iterations=NUMBER_OF_ITERATIONS] [user_id=A_USER_ID] [feature_id=A_FEATURE_ID]'

  if validate_params
    execute
  else
    p usage_message
  end
end

def validate_params
  !ENV['api_key'].nil? && !ENV['base_uri'].nil?
end

def split_client
  api_key = ENV['api_key'].nil? ? 'fake_api_key' : ENV['api_key']
  base_uri = ENV['base_uri'].nil? ? 'fake/api/' : ENV['base_uri']
  SplitIoClient::SplitFactory.new(api_key, base_uri: base_uri, logger: Logger.new('/dev/null').client)
end

def times_per_thread
  iterations = ENV['iterations'].nil? ? 1_000_000 : ENV['iterations'].to_i
  iterations / 4
end

def feature_id
  ENV['feature_id'].nil? ? 'sample_feature' : ENV['feature_id']
end

def user_id
  ENV['user_id'].nil? ? 'fake_id_1' : ENV['user_id']
end

def execute
  threads = []
  puts Benchmark.measure do
    4.times do |_i|
      threads << Thread.new do
        times_per_thread.times do
          split_client.get_treatment user_id, feature_id, attr: 123
        end
      end
    end
    threads.map(&:join)
  end
end
