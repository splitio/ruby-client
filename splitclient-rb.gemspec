# frozen_string_literal: true

lib = File.expand_path('lib', __dir__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require 'splitclient-rb/version'

Gem::Specification.new do |spec|
  spec.name          = 'splitclient-rb'
  spec.version       = SplitIoClient::VERSION
  spec.authors       = ['Split Software']
  spec.email         = ['mauro.sanz@split.io']
  spec.summary       = 'Ruby client for split SDK.'
  spec.description   = 'Ruby client for using split SDK.'
  spec.homepage      = 'https://github.com/splitio/ruby-client'
  spec.license       = 'Apache-2.0'

  spec.files         = `git ls-files -z`.split("\x0").reject { |f| f.match(%r{^(spec|features|ext)/}) }
  spec.require_paths = ['lib']
  spec.required_ruby_version = '>= 2.5.0'

  if defined?(JRUBY_VERSION)
    spec.platform = 'java'
    spec.files.concat(
      %w[ext/murmurhash/MurmurHash3.java
         lib/murmurhash/murmurhash.jar]
    )
  else
    spec.files.concat(
      %w[ext/murmurhash/3_x86_32.c
         ext/murmurhash/3_x64_128.c
         ext/murmurhash/extconf.rb
         ext/murmurhash/murmurhash.c
         ext/murmurhash/murmurhash.h]
    )
    spec.extensions = ['ext/murmurhash/extconf.rb']
  end

  spec.add_development_dependency 'allocation_stats', '~> 0.1'
  spec.add_development_dependency 'bundler', '~> 2.2'
  spec.add_development_dependency 'byebug', '~> 11.1'
  spec.add_development_dependency 'pry', '~> 0.14'
  spec.add_development_dependency 'pry-nav', '~> 1.0'
  spec.add_development_dependency 'rake', '~> 13.0'
  spec.add_development_dependency 'rake-compiler', '~> 1.1'
  spec.add_development_dependency 'rspec', '~> 3.10'
  spec.add_development_dependency 'rubocop', '1.28.2'
  spec.add_development_dependency 'simplecov', '~> 0.20'
  spec.add_development_dependency 'simplecov-json', '~> 0.2'
  spec.add_development_dependency 'timecop', '~> 0.9'
  spec.add_development_dependency 'webmock', '~> 3.14'
  spec.add_development_dependency 'webrick', '~> 1.7'

  spec.add_runtime_dependency 'bitarray', '~> 1.3'
  spec.add_runtime_dependency 'concurrent-ruby', '~> 1.0'
  spec.add_runtime_dependency 'faraday', '>= 1.1', '< 3.0'
  spec.add_runtime_dependency 'faraday-net_http_persistent', '>= 1.0', '< 3.0'
  spec.add_runtime_dependency 'json', '>= 1.8', '< 3.0'
  spec.add_runtime_dependency 'jwt', '>= 1.0.0', '< 3.0'
  spec.add_runtime_dependency 'net-http-persistent', '>= 2.9', '< 5.0'
  spec.add_runtime_dependency 'redis', '>= 4.0.0', '< 6.0'
  spec.add_runtime_dependency 'sin_lru_redux', '~> 2.5'
  spec.add_runtime_dependency 'socketry', '>= 0.4', '< 1.0'
  spec.add_runtime_dependency 'thread_safe', '~> 0.3'
end
