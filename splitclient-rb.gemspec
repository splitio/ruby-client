# coding: utf-8
lib = File.expand_path('../lib', __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require 'splitclient-rb/version'

Gem::Specification.new do |spec|
  spec.name          = "splitclient-rb"
  spec.version       = SplitIoClient::VERSION
  spec.authors       = ["Split Software"]
  spec.email         = ["pato@split.io"]

  spec.summary       = %q{Ruby client for split SDK.}
  spec.description   = %q{Ruby client for using split SDK.}
  spec.homepage      = "https://github.com/splitio/ruby-client"
  spec.license       = "Apache 2.0"

  spec.files         = `git ls-files -z`.split("\x0").reject { |f| f.match(%r{^(test|spec|features)/}) }
  spec.bindir        = "exe"
  spec.executables   = spec.files.grep(%r{^exe/}) { |f| File.basename(f) }
  spec.require_paths = ["lib"]

  spec.add_development_dependency "bundler", "~> 1.11"
  spec.add_development_dependency "rake", "~> 10.0"
  spec.add_development_dependency "rspec"
  spec.add_development_dependency "webmock"
  spec.add_development_dependency "byebug"
  spec.add_development_dependency "pry"
  spec.add_development_dependency "pry-byebug"
  spec.add_development_dependency "simplecov"
  spec.add_development_dependency "allocation_stats"

  spec.add_runtime_dependency "json", ">= 1.8"
  spec.add_runtime_dependency "thread_safe", ">= 0.3"
  spec.add_runtime_dependency "concurrent-ruby", "~> 1.0"
  spec.add_runtime_dependency "faraday", ">= 0.8"
  spec.add_runtime_dependency "net-http-persistent", "~> 2.9"
  spec.add_runtime_dependency "redis", ">= 3.2"
  spec.add_runtime_dependency "digest-murmurhash", ">= 1.1"
end
