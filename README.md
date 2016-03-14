# splitclient-rb

Ruby client for split software. This is provided as a gem that can be installed to your Ruby application

## Installation
----------

 - Once the gem is published you can install it with the following steps:

	Add this line to your application's Gemfile:

	```ruby
	gem 'splitclient-rb'
	```

	And then execute:

	    $ bundle

	Or install it yourself as:

	    $ gem install splitclient-rb

 - If the gem is still unpublished you can install it through this git repository with the following instructions:

	Add these lines to you application's Gemnfile
	```ruby
	gem 'splitclient-rb', :git=>'https://github.com/splitio/ruby-client.git',
	```
	You can also specify any specific branch if necessary
	```ruby
	gem 'splitclient-rb', :git=>'https://github.com/splitio/ruby-client.git', :branch=>'development'
	```
	And then execute:

	    $ bundle install

## Usage
###Quick Setup
------
Within your application you need the following

Require the Split client:
```ruby
require 'splitclient-rb'
```

Create a new split client instance with your API key:
```ruby
split_client = SplitIoClient::SplitClient.new("your_api_key")
```
###Ruby on Rails
----
If you're using Ruby on Rails

Create an initializer file at config/initializers/splitclient.rb and then initialize the split client :
```ruby
Rails.configuration.split_client = SplitIoClient::SplitClient.new("your_api_key")
```
In your controllers, access the client using

```ruby
Rails.application.config.split_client
```

###Configuration
---
By default the split client uses its default configuration, it will be sufficient for most scenarios. However you can also provide custom configuration when initializing the client using an optional hash of options.

The following values can be customized

**base_uri** :  URI for the api endpoints
*defualt value* :  https://sdk.split.io/api/

**local_store** : optional cache storage
*default value* : custom cache local storage

**connection_timeout** :  timeout for network connections in seconds
*default value* =   5

**timeout** : timeout for requests in seconds
*default value* = 2

**fetch_interva**l : time interval for execution of fetches in seconds
*default value* = 60

**push_interval** : time interval for execution of metric posts in seconds
*default value* = 180

**logger** : default logger for messages and errors
*default value* : Ruby logger class set to STDOUT

Example
```ruby
options = {base_uri: 'https://my.app.api/',
           local_store: Rails.cache,
           connection_timeout: 10,
           timeout: 5,
           fetch_interval: 120,
           push_interval: 360,
           logger: Logger.new('logfile.log')}

split_client = SplitIoClient::SplitClient.new("your_api_key", options)
```
### Execution
---
In your application code you just need to call the is_on? method with the required parameters for key and feature name
```ruby
split_client.is_treatment?('key','feature_name','on')
```

For example
```ruby
if split_client.is_treatment?('employee_user_01','view_main_list','on')
   my_app.display_main_list
end
```

## Development

After checking out the repo, run `bin/setup` to install dependencies. You can also run `bin/console` for an interactive prompt that will allow you to experiment.

To install this gem onto your local machine, run `bundle exec rake install`. To release a new version, update the version number in `version.rb`, and then run `bundle exec rake release`, which will create a git tag for the version, push git commits and tags, and push the `.gem` file to [rubygems.org](https://rubygems.org).

## Coverage

The gem uses rspec for unit testing. Under the default `/spec` folder you will find the files for the unit tests and the specs helper file ( spec_helper.rb ). If a new spec file with new unit tests is required you just simply need to create it under the spec foleder and all its test will be executed on the next rspec execution.

To run the suite of unit tests a rake task is provided. It's executed with the following command:

	    $ rake spec

Also, simplecov is used for coverage reporting. After the execution of the rake tastk it will create the `/coverage` folder with coverage reports in pretty HTML format.
Right now, the code coverage of the gem is at about 95%.


## Contributing

Bug reports and pull requests are welcome on GitHub at https://github.com/splitio/ruby-client.


## License

The gem is available as open source under the terms of the [Apache License](http://www.apache.org/licenses/).
