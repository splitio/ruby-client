# Split Ruby SDK

Ruby [Split](https://www.split.io/) SDK client.

## Installation

Install by running:

    $ gem install splitclient-rb

If using [Bundler](https://bundler.io/), add this line to your `Gemfile`:

```ruby
gem 'splitclient-rb'
```

And then run:

    $ bundle install

Or use any specific branch by adding the following to your `Gemfile` instead:

```ruby
gem 'splitclient-rb', git: 'https://github.com/splitio/ruby-client.git', branch: 'branch_name'
```

## Usage

### Quick Setup
---

Within your application, include the Split client using Ruby's `require`:
```ruby
require 'splitclient-rb'
```

Then, create a new split client instance with your API key, which can be found in your Organization Settings page, in the APIs tab.

```ruby
factory  = SplitIoClient::SplitFactoryBuilder.build('YOUR_API_KEY')
split_client = factory.client
```

### Ruby on Rails
---

Create an initializer (typically `config/initializers/split_client.rb`) with the following code:

```ruby
Rails.configuration.split_client = SplitIoClient::SplitFactoryBuilder.build('YOUR_API_KEY').client
```
And use the snippet below to access the client in your controllers:

```ruby
Rails.application.config.split_client
```

### Using the SDK
---

In its simplest form, using the SDK is reduced to calling the `get_treatment` method of the SDK client to decide what version of your features your customers should be served for a specific feature and user. You can then use an if-else-if block for the different treatments that you defined in the Split UI:

```ruby
treatment = split_client.get_treatment('user_id', 'feature_name');

if treatment == 'on'
  # insert code here to show on treatment
elsif treatment == 'off'
  # insert code here to show off treatment
else
  # handle the client returning the control treatment
end
```

For features that use targeting rules based on user attributes, you can call the `get_treatment` method the following way:

```ruby
split_client.get_treatment('user_id','feature_name', attr: 'val')
```

e.g.
```ruby
if split_client.get_treatment('employee_user_01','view_main_list', age: 35)
   my_app.display_main_list
end
```

Also, you can you can provide two different keys - one for matching and the other for bucketing:
```ruby
split_client.get_treatment(
	{ matching_key: 'subscriber_id', bucketing_key: 'user_id' },
	'feature_name',
	attr: 'val'
)
```
An scenario that requires the usage of both keys is a visitor user that browses the site and at some point gets logged into the system: as an anonymous visitor, the user browses the home page and is given the `new_homepage` treatment based on her visitor id. If the visitor signs up and turns into a subscriber, then upon being given her `subscriber_id`, Split may decide to give her the old_homepage treatment. This is of course, the opposite of the desired outcome, as the visitor's entire homepage experience would change as soon as she signs up.

 Split solves this situation by introducing the concept of a matching_key and a bucketing key. By providing the `subscriber_id` as the `matching_key` and the `visitor_id` as the `bucketing_key`, Split will give the same treatment back to the user that it used to give to the visitor.

 **Note**: read more about this topic [here](https://docs.split.io/docs/anonymous-to-logged-in).

The `bucketing_key` may be `nil`. In that case the `matching_key` would be used instead, so calling:
```ruby
split_client.get_treatment(
	{ matching_key: 'subscriber_id' },
	'feature_name',
	attr: 'val'
)
```
It's exactly the same as calling:
```ruby
split_client.get_treatment('subscriber_id' ,'feature_name', attr: 'val')
```
**Important:** `matching_key` cannot be nil.

#### Split Manager

For some advanced use cases you can use the Split Manager. To get a `manager` instance, do:

```ruby
split_manager = SplitIoClient::SplitFactoryBuilder.build('your_api_key', options).manager
```
_Or simply call `#manager` in your factory instance if you built it previously._

As an example, using the manager you could get a list of your splits by doing:

```ruby
split_manager.splits
```

Which would produce an output similar to:

```ruby
[
	{
		name: 'some_feature',
		traffic_type_name: nil,
		killed: false,
		treatments: nil,
		change_number: 1469134003507
	},
	{
		name: 'another_feature',
		traffic_type_name: nil,
		killed: false,
		treatments: nil,
		change_number: 1469134003414
	},
	{
		name: 'even_more_features',
		traffic_type_name: nil,
		killed: false,
		treatments: nil,
		change_number: 1469133991063
	},
	{
		name: 'yet_another_feature',
		traffic_type_name: nil,
		killed: false,
		treatments: nil,
		change_number: 1469133757521
	}
]
 ```

 #### Localhost Mode

 You can run the SDK in _localhost_ mode. In this mode, the SDK won't actually communicate with the Split API, but it'll rather return treatments based on a `.split` file on your local environment. This file must be a list of `split_name treatment_name_to_be_returned` entries. e.g.:

 ```
 reporting_v2 on
 double_writes_to_cassandra off
 new-navigation v3
 ```

Using the file above, when calling:
```ruby
split_client.get_treatment('foo', 'reporting_v2')
```

The split client will return `on`. Note that this will be true for any bucketing or matching key.

 To configure the SDK to work in localhost mode, use `localhost` as the API key:

 ```ruby
 factory = SplitIoClient::SplitFactoryBuilder.build('localhost', path: '/where/to-look-for/<file_name>')
 split_client = factory.client
 ```

 By default, the SDK will look in your home directory (i.e. `~`) for the `.split` file. You can change this location by specifying an absolute path instead.

 When in localhost mode, you can make use of the SDK ability to automatically refresh the splits from the `.split` file. To do that, just specify a reload rate in seconds when building the split factory instance, like this:

 ```ruby
 factory = SplitIoClient::SplitFactoryBuilder.build('localhost', path: '/where/to-look-for/<file_name>', reload_rate: 3)
 ```

## Advanced Configuration

Split client's default configuration should cover most scenarios. However, you can also provide custom configuration settings when initializing the factory using a hash of options. e.g.:

```ruby
options = {
  impressions_refresh_rate: 10,
  debug_enabled: true,
  transport_debug_enabled: false
}

factory = SplitIoClient::SplitFactoryBuilder.build('your_api_key'], options)
```

The following values can be customized:

**base_uri** :  URI for the api endpoints.

*default value* = `https://sdk.split.io/api/`

**connection_timeout** : Http client connection timeout (in seconds).

*default value* = `5`

**read_timeout** : Http socket read timeout (in seconds).

*default value* = `5`

**features_refresh_rate** : The SDK polls Split servers for changes to feature Splits every X seconds, where X is this property's value.

*default value* = `30`

**segments_refresh_rate** : The SDK polls Split servers for changes to segments every X seconds, where X is this property's value.

*default value* = `60`

**metrics_refresh_rate** : The SDK sends and flushes diagnostic metrics to Split servers every X seconds where X is this property's value.

*default value* = `60`

**impressions_refresh_rate** : The treatment log captures which customer saw what treatment ("on", "off", etc) at what time. This parameter controls how often this log is flushed back to Split servers to power analytics (in seconds).

*default value* = `60`

**impressions_queue_size** : The size of the impressions queue in case of `cache_adapter == :memory`.

*default value* = 5000

**impressions_bulk_size** : Maximum number of impressions to be sent to Split servers on each post.

*default value* = defaults to `impressions_queue_size`

**debug_enabled** : Enables extra logging (verbose mode).

*default value* = `false`

**transport_debug_enabled** : Super verbose mode that prints network payloads among others.

*default value* = `false`

**logger** : Default logger for messages and errors.

*default value* = `Logger.new($stdout)`

**impression_listener** : Route impressions' information to a location of your choice (in addition to the SDK servers). _See [Impression Listener](#impression-listener) section for specifics._

*default value* = (no impression listener)

**block_until_ready** : The SDK will block your app for the provided amount of seconds until it's ready. A `SplitIoClient::SDKBlockerTimeoutExpiredException` will be thrown If the provided time expires. When `0` is provided, the SDK runs in non-blocking mode.

*default value* = `0`

**labels_enabled** : Allows preventing labels from being sent to the Split servers, as they may contain sensitive information.

*default value* = `true`

**mode** : See [SDK Modes](#sdk-modes).

*default value* = `:standalone`

**cache_adapter** : Where to store data (splits, segments, and impressions) in between calls to the the Split servers. Supported options are `:memory` (default) and `:redis`.

_To use Redis, include `redis-rb` in your app's Gemfile._

*default value* = `:memory`

**redis_namespace** : Prefix to add to elements in Redis cache when having to share redis with other applications.

*default value* = `SPLITIO`

**language** : SDK language (used in the Redis namespace for metrics and impressions, also included in requests' headers).

*default value* = `'ruby'`

**version** : SDK version (used in the Redis namespace for metrics and impressions, also included in requests' headers).

*default value* = (current version of the SDK)

**machine_ip** : SDK machine ip (used in the Redis namespace for metrics and impressions, also included in requests' headers).

*default value* = (your current host's ip)

**machine_name** : SDK machine name (used in the Redis namespace for metrics and impressions, also included in requests' headers).

*default value* = (your current hostname)

**cache_ttl** : Time to live in seconds for the memory cache values when using Redis.

*default value* = `5`

**max_cache_size** : Maximum number of items held in the memory cache values when using Redis. When cache is full an LRU strategy for pruning shall be used.

*default value* = `500`

**redis_url** : Redis URL or hash with configuration for the SDK to connect to. See [Redis#initialize](https://www.rubydoc.info/github/redis/redis-rb/Redis%3Ainitialize) for detailed information.

*default value* = `'redis://127.0.0.1:6379/0'`

_You can also use [Redis Sentinel](https://redis.io/topics/sentinel) by providing an array of sentinels in the Redis configuration:_

```ruby
SENTINELS = [{host: '127.0.0.1', port: 26380},
             {host: '127.0.0.1', port: 26381}]

options = {
  # Other options here
  redis_url: { url: 'redis://mymaster', sentinels: SENTINELS, role: :master }
}
```
### Sample Configuration Using Redis
---

```ruby
options = {
  connection_timeout: 10,
  read_timeout: 5,
  features_refresh_rate: 120,
  segments_refresh_rate: 120,
  metrics_refresh_rate: 360,
  impressions_refresh_rate: 360,
  logger: Logger.new('logfile.log'),
  cache_adapter: :redis,
  mode: :standalone,
  redis_url: 'redis://127.0.0.1:6379/0'
}
begin
  split_client = SplitIoClient::SplitFactoryBuilder.build('YOUR_API_KEY', options).client
rescue SplitIoClient::SDKBlockerTimeoutExpiredException
  # Code to treat raised exception
end
```

### Logging
---

By default, the SDK makes use of Ruby stdlib's `Logger` class to log errors and events. You can change the following options when configuring the SDK in your application:

```ruby
logger: Logger.new('logfile.log'), # Logger class instance.
debug_enabled: true, # Verbose logging.
transport_debug_enabled: true # Super verbose logging, including http request data.
```

_Refer to [Advanced Configuration](#advanced-configuration) for more information._

#### Impression Listener

The SDK provides an optional featured called Impression Listener, that captures every single impression in your app.

To set up an Impression Listener, define a class that implements a `log` instance method, which must receive the `impression` argument. e.g.:

```ruby
class MyImpressionListener
  def log(impression)
    Logger.new($stdout).info(impression)
  end
end
```

In the example above, the listener simply takes an impression and logs it to the stdout. By providing a specific listener, you could send this information to a location of your choice. To use this feature, you need to specify the class name in the corresponding option of your configuration (i.e. initializer) like this:

```ruby
{
  # other options
  impression_listener: MyImpressionListener.new # remember to initialize your class here
}
```

### SDK Modes
---

The SDK is capable of running in two different modes to fit in different infrastructure configurations:

- `:standalone` - (default) : The SDK will retrieve information (e.g. split definitions) periodically from the Split servers, and store it in the chosen cache (memory / Redis). It'll also store the application execution information (e.g. impressions) in the cache and send it periodically to the Split servers. As it name implies, in this mode, the SDK neither relies nor synchronizes with any other component.
- `:consumer` - If using a load balancer or more than one SDK in your application, guaranteeing that all changes in split definitions are picked up by all SDK instances at the same time is highly recommended in order to ensure consistent results across your infrastructure (i.e. getting the same treatment for a specific split and user pair). To achieve this, use the [Split Synchronizer](https://docs.split.io/docs/split-synchronizer)) and setup your SDKs to work in the `consumer` mode. Setting the components this way, all communication with the Split server is orchestrated by the Synchronizer, while the SDKs pick up definitions and store the execution information from / into a shared Redis data store.

_You can choose between these 2 modes setting the `mode` option in the config._

## SDK Server Compatibility

The Split Ruby SDK has been tested as a standalone app as well as using the following web servers:
  - Thin
  - Puma
  - Passenger
  - Unicorn

For other setups, please reach out to [support@split.io](mailto:support@split.io).

### Server Compatibility Notes
---

#### Unicorn and Puma in cluster mode (only for "memory mode")

During the start of your application, the SDK spawns multiple threads. Each thread has an infinite loop inside,
which is used to fetch splits/segments or send impressions/metrics to the Split service continuously.
When using Unicorn or Puma in cluster mode (i.e. with `workers` > 0) the application
server will spawn multiple child processes, but they won't recreate the threads that existed in the parent process.
So, if your application is running in Unicorn or Puma in cluster mode you need to make two small extra steps.

For both servers you will need to have the following line in your `config/initializers/splitclient.rb`:

```ruby
Rails.configuration.split_factory = factory
```

#### Unicorn

If you’re using Unicorn you’ll need to include these lines in your Unicorn config (likely `config/unicorn.rb`):

```ruby
before_fork do |server, worker|
  # keep your existing before_fork code if any
  Rails.configuration.split_factory.stop!
end

after_fork do |server, worker|
  # keep your existing after_fork code if any
  Rails.configuration.split_factory.resume!
end
```

#### Puma

If using Puma in cluster mode, add these lines to your Puma config (likely `config/puma.rb`):

```ruby
before_fork do
  # keep your existing before_fork code if any
  Rails.configuration.split_factory.stop!
end

on_worker_boot do
  # keep your existing on_worker_boot code if any
  Rails.configuration.split_factory.resume!
end
```

By doing the above, the SDK will recreate the threads for each new worker and prevent the master process (that doesn't handle requests) from needlessly querying the Split service.

## Proxy Support

SDK uses the `http_proxy` environment variable. Assign your proxy address to the variable value in the following format, and the SDK will make use of it:

```
http_proxy=http://username:password@hostname:port
```

## Development Notes

Check out the repository and run `bin/setup` to install dependencies. You can also run `bin/console` to get an interactive prompt.

To install this gem onto your local machine, run `bundle exec rake install`.

### Tests & Coverage
---

The gem uses `rspec` for unit testing. You can find the files for the unit tests and the specs helper file (`spec_helper.rb`) under the default `/spec` folder.

To run all the specs in the `spec` folder, use the provided rake task (_make sure Redis is running in localhost_):

```bash
  bundle exec rspec
```

`Simplecov` is used for coverage reporting. Upon executing the rake task it will store the reports in the `/coverage` folder.

### Benchmarks
---

To benchmark the hashing algorithms (MurmurHash) run:

```bash
bundle exec rake benchmark_hashing_algorithm
```

### Contribute
---

Bug reports and pull requests are welcome on GitHub at https://github.com/splitio/ruby-client.

### Release
---

To build and release a new version of the gem, document any changes into the `CHANGES.txt` and the `NEWS` files. Then, increase the version number in `version.rb`.
**Note**: This step assumes that all new features and fixes have been merged into the `development` branch, tested, validated, and finally merged into the `master` branch of the `ruby-client` repository.

To build a new version of the gem after making the changes specified above, run:

```bash
gem build splitclient-rb.gemspec
```

That will generate a `splitclient-rb-x.x.x.gem` file, with the corresponding version information on it.
To release the new version of the gem at [rubygems.org](rubygems.org) run the following command:

```bash
gem push splitclient-rb-x.x.x.gem
```

_A valid rubygems username and password is required._

Once released, `splitclient-rb-x.x.x` version will be available for use in any ruby application.

To get a specific gem version in a Rails application that uses Bundler, add this line to your gemfile:

```ruby
gem 'splitclient-rb', '~> x.x.x'
```

## License

The gem is available as open source under the terms of the [Apache License](http://www.apache.org/licenses/).
