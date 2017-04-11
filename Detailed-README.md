# Split Ruby SDK

Ruby SDK for Split software, provided as a gem that can be installed to your Ruby application.

## Installation
---

 - Once the gem is published you can install it with the following steps:

	Add this line to your application's Gemfile:

	```ruby
	gem 'splitclient-rb'
	```

	And then execute:

	    $ bundle install

	Or install it yourself as:

	    $ gem install splitclient-rb

 - You can also use the most recent version from github:

	Add these lines to you application's `Gemfile`:
	```ruby
	gem 'splitclient-rb', git: 'https://github.com/splitio/ruby-client.git',
	```
	You can also use any specific branch if necessary:
	```ruby
	gem 'splitclient-rb', git: 'https://github.com/splitio/ruby-client.git', branch: 'development'
	```
	And then execute:

	    $ bundle install

## Usage

### Quick Setup
---

Within your application you need the following:

Require the Split client:
```ruby
require 'splitclient-rb'
```

Create a new split client instance with your API key:
```ruby
factory  = SplitIoClient::SplitFactoryBuilder.build('YOUR_API_KEY').client
split_client = factory.client
```

For advance use cases you can also obtain a `manager` instance from the factory.
```ruby
manager = factory.manager
```

#### Localhost mode

You can run SDK in so called "localhost" mode. In this mode SDK won't hit Split API and return treatments based on ".split" file on your local machine. The format of this file is two columns separated by whitespace. The left column is the Split name, the right column is the treatment name. Here is a sample file:

```
# this is a comment

# split_client.get_treatment('foo', 'reporting_v2') => 'on'

reporting_v2 on
double_writes_to_cassandra off
new-navigation v3

```

To use SDK in the localhost mode you should pass `localhost` as an API key like this:

```ruby
factory = SplitIoClient::SplitFactoryBuilder.build('localhost', path: '/where/to-look-for/<file_name>')
split_client = factory.client
```

By default SDK will look in your home directory (i.e. `~`) for a `.split` file, but you can specify a different
file name (full path) to look for the file (note: you must provide absolute path):

When in localhost mode you can make use of the SDK ability to automatically refresh splits from file, to do that just specify reload rate in seconds like this:

```ruby
factory = SplitIoClient::SplitFactoryBuilder.build('localhost', path: '/where/to-look-for/<file_name>', reload_rate: 3)
```

### Ruby on Rails
---

Create an initializer: `config/initializers/splitclient.rb` and then initialize the split client:

```ruby
Rails.configuration.split_client = SplitIoClient::SplitFactoryBuilder.build('YOUR_API_KEY').client
```
In your controllers, access the client using:

```ruby
Rails.application.config.split_client
```

### Configuration
---

Split client's default configuration should be sufficient for most scenarios. However you can also provide custom configuration when initializing the client using an optional hash of options.

The following values can be customized:

**base_uri** :  URI for the api endpoints

*defualt value* = `https://sdk.split.io/api/`

**connection_timeout** :  timeout for network connections in seconds

*default value* = `5`

**read_timeout** : timeout for requests in seconds

*default value* = `5`

**features_refresh_rate** : The SDK polls Split servers for changes to feature roll-out plans. This parameter controls this polling period in seconds
split_client.get_treatment('user_id','feature_name', attr: 'val')
*default value* = `30`

**segments_refresh_rate** : The SDK polls Split servers for changes to segment definitions. This parameter controls this polling period in seconds

*default value* = `60`

**metrics_refresh_rate** : The SDK sends diagnostic metrics to Split servers. This parameters controls this metric flush period in seconds

*default value* = `60`

**impressions_refresh_rate** : The SDK sends information on who got what treatment at what time back to Split servers to power analytics. This parameter controls how often this data is sent to Split servers in seconds

**impressions_queue_size** : The size of the impressions queue in case of `cache_adapter == :memory` and the size impressions batch to be fetched from Redis in case of `cache_adapter == :redis`. Use `-1` to disable impressions.

*default value* = `60`

**debug_enabled** : Enables extra logging

*default value* = `false`

**transport_debug_enabled** : Enables extra transport logging

*default value* = `false`

**logger** : default logger for messages and errors

*default value* = `Logger.new($stdout)`

**ready** : The SDK will block your app for provided amount of seconds until it's ready. If timeout expires `SplitIoClient::SDKBlockerTimeoutExpiredException` will be thrown. If `0` provided, then SDK would run in non-blocking mode

*default value* = `0`

**labels_enabled** : Enables sending labels along with sensitive information

*default value* = `true`

**mode** : See [SDK modes section](#sdk-modes).

*default value* = `:standalone`

#### Cache adapter

The SDK needs some container to store data, i.e. splits/segments/impressions. By default it will store everything in the application's memory, but you can also use Redis.

To use Redis, you have to include `redis-rb` in your app's Gemfile.

**cache_adapter** : Supported options: `:memory`, `:redis`

*default value* = `memory`

**language** : SDK runner language (used in metrics/impressions Redis namespace)

*default value* = `'ruby'`

**version** : SDK runner version (used in metrics/impressions Redis namespace)

*default value* = `current version of Ruby SDK`

**machine_ip** : SDK runner machine ip (used in metrics/impressions Redis namespace)

*default value* = `current host's ip`

**machine_name** : SDK runner machine name (used in metrics/impressions Redis namespace)

*default value* = `current hostname`

**redis_url** : Redis URL or hash with configuration for SDK to connect to.

*default value* = `'redis://127.0.0.1:6379/0'`

You can also use Sentinel like this:

```ruby
SENTINELS = [{host: '127.0.0.1', port: 26380},
             {host: '127.0.0.1', port: 26381}]

redis_connection = { url: 'redis://mymaster', sentinels: SENTINELS, role: :master }

options = {
  # Other options here
  redis_url: redis_connection
}
```

Example using Redis
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
  # Some arbitrary actions
end
```

#### Unicorn

When using Unicorn without Redis (i.e. in memory mode) it's highly recommended to include the startup code above inside Unicorn's `after_fork` hook:

*unicorn.rb*
```ruby
# Unicorn configuration
after_fork do
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
    # Some arbitrary actions
  end
end
```

When initializing the SDK this way, SDK will only run HTTP requests from workers, not master process.

#### IMPORTANT

For now, SDK does not support both `producer` mode and `ready`. You must either run SDK in `standalone` mode, or do not use `ready` option.

This begin-rescue-end block is optional, you might want to use it to catch timeout expired exception and apply some logic.

### Execution
---

In your application code you just need to call the `get_treatment` method with the required parameters for key and feature name:
```ruby
split_client.get_treatment('user_id','feature_name', attr: 'val')
```

For example
```ruby
if split_client.get_treatment('employee_user_01','view_main_list', age: 35)
   my_app.display_main_list
end
```

Also, you can use different keys for actually getting treatment and sending impressions to the server:
```ruby
split_client.get_treatment(
	{ matching_key: 'user_id', bucketing_key: 'private_user_id' },
	'feature_name',
	attr: 'val'
)
```
When it might be useful? Say, you have a user browsing your website and not signed up yet. You assign some internal id to that user (i.e. bucketing_key) and after user signs up you assign him a matching_key.
By doing this you can provide both anonymous and signed up user with the same treatment.

`bucketing_key` may be `nil` in that case `matching_key` would be used as a key, so calling
```ruby
split_client.get_treatment(
	{ matching_key: 'user_id' },
	'feature_name',
	attr: 'val'
)
```
Is exactly the same as calling
```ruby
split_client.get_treatment('user_id' ,'feature_name', attr: 'val')
```
`bucketing_key` must not be nil

Also you can use the split manager:

```ruby
split_manager = SplitIoClient::SplitFactoryBuilder.build('your_api_key', options).manager
```

With the manager you can get a list of your splits by doing:

```ruby
manager.splits
```

And you should get something like this:

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

### SDK Modes

By default SDK would run alongside with your application and will be run in `standalone` mode, which includes two modes:
- `producer` - storing information from the Splits API in the chosen cache
- `consumer` - retrieving data from the cache and providing `get_treatment` interface

As you might think, you can choose between these 3 modes by providing `mode` option in the config.

#### Producer mode

If you have, say, one Redis cache which is used by several Split SDKs at once, e.g.: Python and Ruby, you want to have only one of them to write data to Redis, so it would remain consistent. That's why we have producer mode.

SDK can be ran in `producer` mode both in the scope of the application (e.g. as a part of the Rails app), and as a separate process. Let's see what steps are needed to run it as a separate process:

- You need to create a config file with .yml extension. All options specified in the above example section are valid, but you should write them in the YAML format, like this:

```yaml
---
:api_key: 'SECRET_API_KEY'
:connection_timeout: 10
:read_timeout: 5
:features_refresh_rate: 120
:segments_refresh_rate: 120
:metrics_refresh_rate: 360
:impressions_refresh_rate: 360
:cache_adapter: :redis
:mode: :producer
:redis_url: 'redis://127.0.0.1:6379/0'
```


- Install binstubs
```ruby
bundle binstubs splitclient-rb
```

- Run the executable provided by the SDK:
```ruby
bundle exec bin/splitio -c ~/path/to/config/file.yml
```

Also, you can pass options directly to the cli command, like this:
```
bundle exec bin/splitio -c ~/path/to/config/file.yml --debug
```

Note: options passed through cli have higher priority than those specified in the configuration file. To see the full list of supported options you can run:
```
bundle exec bin/splitio -h
```
## Server support

Currently SDK supports:
  - Thin
  - Puma
  - Passenger
  - Unicorn

Other servers should work fine as well, but haven't been tested.

### Unicorn

If you're using Unicorn in the `memory` mode you'll need to include this line in your unicorn config (probably `config/unicorn.rb`):

```ruby
after_fork do |server, worker|
  Rails.configuration.split_factory.resume! if worker.nr > 0
end
```

Also, you will need to have the following line in your `config/initializers/splitclient.rb`:

```ruby
Rails.configuration.split_factory = factory
```

## Framework support

Currently SDK supports:
  - Rails

SDK should work with other frameworks too, but for now it has been tested only with Rails

## Development

After checking out the repo, run `bin/setup` to install dependencies. You can also run `bin/console` for an interactive prompt that will allow you to experiment.

To install this gem onto your local machine, run `bundle exec rake install`. To release a new version, update the version number in `version.rb`, and then run `bundle exec rake release`, which will create a git tag for the version, push git commits and tags, and push the `.gem` file to [rubygems.org](https://rubygems.org).

## Coverage

The gem uses rspec for unit testing. Under the default `/spec` folder you will find the files for the unit tests and the specs helper file ( spec_helper.rb ). If a new spec file with new unit tests is required you just simply need to create it under the spec folder and all its test will be executed on the next rspec execution.

To run the suite of unit tests a rake task is provided.

Make sure redis is running in localhost at redis://127.0.0.1:6379/0 and then just run:
```bash
  SPLITCLIENT_ENV=test bundle exec rspec spec
```

Also, simplecov is used for coverage reporting. After the execution of the rake task it will create the `/coverage` folder with coverage reports in pretty HTML format.
Right now, the code coverage of the gem is at about 95%.

## Release

```bash
gem build splitclient-rb.gemspec
```

This will generate a file gemspec with the right version, then:

```bash
gem push splitclient-rb-<VERSION>.gem
```

## Benchmarking

To benchmark hashing algorithms (currently we're using MurmurHash) you'll need to run:

```bash
bundle exec rake benchmark_hashing_algorithm
```

## Contributing

Bug reports and pull requests are welcome on GitHub at https://github.com/splitio/ruby-client.

## Gem version publish

To build a new version of the gem, after you have finished the desired changes, documented the CHANGES.txt and the NEWS, as well as named it properly in the version.rb. This steps assume that all of your new cool features and fixes have been merged into development, and into master branches of the ruby-client repo. Once that is ready to go, you will have to run the build command to obtain a .gem file:

```bash
gem build splitclient-rb.gemspec
```

That will generate a splitclient-rb-x.x.x.gem file, with the corresponding version information on it.
To publish this new version of the gem at rubygems.org you must run the following command:

```bash
gem push splitclient-rb-x.x.x.gem
```

A valid rubygems username and password will be required.

After this action, the new splitclient-rb-x.x.x version is available for its use from any ruby app.

So for instance in a rails app Gemfile, you could add the:

```ruby
gem 'splitclient-rb', '~> x.x.x'
```

line to have the latest version of the gem ready to be used.

## License

The gem is available as open source under the terms of the [Apache License](http://www.apache.org/licenses/).
