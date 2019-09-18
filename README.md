# Split Ruby SDK
[![Build Status](https://travis-ci.com/splitio/ruby-client.svg?branch=master)](https://travis-ci.com/splitio/ruby-client)

## Overview
This SDK is designed to work with [Split](https://www.split.io), the platform for controlled rollouts, serving features to your users via the Split feature flag to manage your complete customer experience.

## Compatibility
The Ruby SDK support Ruby version 2.3.0 or later and JRuby or 9.1.17 o later.

Also the Ruby SDK has been tested as a standalone app as well as using the following web servers:
 - Puma
 - Passenger
 - Unicorn

For other setups, please reach out to [support@split.io](mailto:support@split.io).

## Development
### Building the SDK
To install this gem dependencies onto your local machine, run `bundle exec rake install`.

### Benchmarks
To benchmark the hashing algorithms (MurmurHash) run:

```bash
bundle exec rake compile:murmurhash
```

### Running tests
The gem uses `rspec` for unit testing. You can find the files for the unit tests and the specs helper file (`spec_helper.rb`) under the default `/spec` folder.

To run all the specs in the `spec` folder, use the provided rake task (_make sure Redis is running in localhost_):

```bash
  bundle exec rspec
```

`Simplecov` is used for coverage reporting. Upon executing the rake task it will store the reports in the `/coverage` folder.

## Contributing
Please see [Contributors Guide](CONTRIBUTORS-GUIDE.md) 
 
## License
The gem is available as open source under the terms of the [Apache License](http://www.apache.org/licenses/).

## About Split 
Split is the leading Feature Delivery Platform for engineering teams that want to confidently release features as fast as they can develop them.
Split’s fine-grained management, real-time monitoring, and data-driven experimentation ensure that new features will improve customer experience without breaking or degrading performance.
Companies like Twilio, Salesforce, GoDaddy and WePay trust Split to power their feature delivery.
 
To learn more about Split, contact hello@split.io, or get started with feature flags for free at https://www.split.io/signup.
 
Split has built and maintains a SDKs for:
 
* Java [Github](https://github.com/splitio/java-client) [Docs](http://docs.split.io/docs/java-sdk-guide)
* Javascript [Github](https://github.com/splitio/javascript-client) [Docs](http://docs.split.io/docs/javascript-sdk-overview)
* Node [Github](https://github.com/splitio/javascript-client) [Docs](http://docs.split.io/docs/nodejs-sdk-overview)
* .NET [Github](https://github.com/splitio/.net-core-client) [Docs](http://docs.split.io/docs/net-sdk-overview)
* Ruby [Github](https://github.com/splitio/ruby-client) [Docs](http://docs.split.io/docs/ruby-sdk-overview)
* PHP [Github](https://github.com/splitio/php-client) [Docs](http://docs.split.io/docs/php-sdk-overview)
* Python [Github](https://github.com/splitio/python-client) [Docs](http://docs.split.io/docs/python-sdk-overview)
* GO [Github](https://github.com/splitio/go-client) [Docs](http://docs.split.io/docs/go-sdk-overview)
* Android [Github](https://github.com/splitio/android-client) [Docs](https://docs.split.io/docs/android-sdk-overview)
* IOS [Github](https://github.com/splitio/ios-client) [Docs](https://docs.split.io/docs/ios-sdk-overview)
 
For a comprehensive list of opensource projects visit our [Github page](https://github.com/splitio?utf8=%E2%9C%93&query=%20only%3Apublic%20).
 
**Learn more about Split:** 
Visit [split.io/product](https://www.split.io/product) for an overview of Split, or visit our documentation at [docs.split.io](http://docs.split.io) for more detailed information.