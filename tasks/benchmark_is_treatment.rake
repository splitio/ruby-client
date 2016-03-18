desc "Benchmark the is_treatment? method call"

# Usage:
# rake benchmark [iterations=NUMBER_OF_ITERATIONS] [api_key=YOUR_API_KEY] [base_uri=YOUR_API_BASE_URI] [user_id=A_USER_ID] [feature_id=A_FEATURE_ID]
task :benchmark do
  require 'benchmark'
  require 'splitclient-rb'
  p "Usage: rake benchmark [iterations=NUMBER_OF_ITERATIONS] [api_key=YOUR_API_KEY] [base_uri=YOUR_API_BASE_URI] [user_id=A_USER_ID] [feature_id=A_FEATURE_ID]"

  iterations = ENV['iterations'].nil? ? 1000000 : ENV['iterations'].to_i
  api_key = ENV['api_key'].nil? ? "42pi6uaekqtnbu4erl5oaroj1spb65el7dak" : ENV['api_key']
  base_uri = ENV['base_uri'].nil? ? "http://sdk-loadtesting.split.io/api/" : ENV['base_uri']
  user_id = ENV['user_id'].nil? ? "fake_id_1" : ENV['user_id']
  feature_id = ENV['feature_id'].nil? ? "sample_feature" : ENV['feature_id']

  split_client = SplitIoClient::SplitClient.new(api_key, {base_uri: base_uri})
  Benchmark.bm do |bm|
    bm.report do
      iterations.times do
        Benchmark.measure { split_client.get_treatment user_id, feature_id }
      end
    end
  end
end
