# Split SDK for Ruby
![Build Status](https://github.com/splitio/ruby-client/actions/workflows/ci.yml/badge.svg?branch=master)

## Overview
This SDK is designed to work with Split, the platform for controlled rollouts, which serves features to your users via a Split feature flag to manage your complete customer experience.
 
[![Twitter Follow](https://img.shields.io/twitter/follow/splitsoftware.svg?style=social&label=Follow&maxAge=1529000)](https://twitter.com/intent/follow?screen_name=splitsoftware)

## Compatibility
The Ruby SDK support Ruby version 2.5.0 or later and JRuby or 9.1.17 o later.

Also the Ruby SDK has been tested as a standalone app as well as using the following web servers:
 - Puma
 - Passenger
 - Unicorn

For other setups, please reach out to [support@split.io](mailto:support@split.io).

## Getting started
Below is a simple example that describes the instantiation and most basic usage of our SDK:
```ruby
require 'splitclient-rb'

split_factory = SplitIoClient::SplitFactory.new('SDK_API_KEY')
split_client = split_factory.client

begin  
  split_client.block_until_ready  
rescue SplitIoClient::SDKBlockerTimeoutExpiredException
  puts 'SDK is not ready. Decide whether to continue or abort execution'  
end  

treatment = split_client.get_treatment('CUSTOMER_ID', 'SPLIT_NAME');

if treatment == 'on'
  # insert code here to show on treatment
elsif treatment == 'off'
  # insert code here to show off treatment
else
  # insert your control treatment code here
end
```
For multi-process environments you also need to setup Split Synchronizer. See [Sharing state: Redis integration](https://help.split.io/hc/en-us/articles/360020673251-Ruby-SDK#sharing-state-redis-integration)
 
Please refer to [our official docs](https://help.split.io/hc/en-us/articles/360020673251-Ruby-SDK) to learn about all the functionality provided by our SDK and the configuration options available for tailoring it to your current application setup.

## Submitting issues
The Split team monitors all issues submitted to this [issue tracker](https://github.com/splitio/ruby-client/issues). We encourage you to use this issue tracker to submit any bug reports, feedback, and feature enhancements. We'll do our best to respond in a timely manner.

## Contributing
Please see [Contributors Guide](CONTRIBUTORS-GUIDE.md) to find all you need to submit a Pull Request (PR).
 
## License
Licensed under the Apache License, Version 2.0. See: [Apache License](http://www.apache.org/licenses/).

## About Split 
Split is the leading Feature Delivery Platform for engineering teams that want to confidently deploy features as fast as they can develop them. Split’s fine-grained management, real-time monitoring, and data-driven experimentation ensure that new features will improve the customer experience without breaking or degrading performance. Companies like Twilio, Salesforce, GoDaddy and WePay trust Split to power their feature delivery.
 
To learn more about Split, contact hello@split.io, or get started with feature flags for free at https://www.split.io/signup.
 
Split has built and maintains SDKs for:
 
* Java [Github](https://github.com/splitio/java-client) [Docs](https://help.split.io/hc/en-us/articles/360020405151-Java-SDK)
* Javascript [Github](https://github.com/splitio/javascript-client) [Docs](https://help.split.io/hc/en-us/articles/360020448791-JavaScript-SDK)
* Node [Github](https://github.com/splitio/javascript-client) [Docs](https://help.split.io/hc/en-us/articles/360020564931-Node-js-SDK)
* .NET [Github](https://github.com/splitio/dotnet-client) [Docs](https://help.split.io/hc/en-us/articles/360020240172--NET-SDK)
* Ruby [Github](https://github.com/splitio/ruby-client) [Docs](https://help.split.io/hc/en-us/articles/360020673251-Ruby-SDK)
* PHP [Github](https://github.com/splitio/php-client) [Docs](https://help.split.io/hc/en-us/articles/360020350372-PHP-SDK)
* Python [Github](https://github.com/splitio/python-client) [Docs](https://help.split.io/hc/en-us/articles/360020359652-Python-SDK)
* GO [Github](https://github.com/splitio/go-client) [Docs](https://help.split.io/hc/en-us/articles/360020093652-Go-SDK)
* Android [Github](https://github.com/splitio/android-client) [Docs](https://help.split.io/hc/en-us/articles/360020343291-Android-SDK)
* iOS [Github](https://github.com/splitio/ios-client) [Docs](https://help.split.io/hc/en-us/articles/360020401491-iOS-SDK)
 
For a comprehensive list of open source projects visit our [Github page](https://github.com/splitio?utf8=%E2%9C%93&query=%20only%3Apublic%20).
 
**Learn more about Split:**
 
Visit [split.io/product](https://www.split.io/product) for an overview of Split, or visit our documentation at [help.split.io](http://help.split.io) for more detailed information.
