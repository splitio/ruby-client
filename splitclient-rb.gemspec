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

  spec.files         = `git ls-files -z`.split("\x0").reject { |f| f.match(%r{^(spec|features|ext)/}) }

  spec.bindir        = "exe"
  spec.executables   = spec.files.grep(%r{^exe/}) { |f| File.basename(f) }
  spec.require_paths = ["lib"]

  if defined?(JRUBY_VERSION)
    spec.platform = 'java'
    spec.files << 'ext/murmurhash/MurmurHash3.java'
  else
    spec.files.concat(%w(
      ext/murmurhash/3_x86_32.c
      ext/murmurhash/extconf.rb
      ext/murmurhash/murmurhash.c
      ext/murmurhash/murmurhash.h)
    )
    spec.extensions = ["ext/murmurhash/extconf.rb"]
  end

  spec.add_development_dependency "bundler", "~> 1.11"
  spec.add_development_dependency "rake", "~> 10.0"
  spec.add_development_dependency "rake-compiler"
  spec.add_development_dependency "rspec"
  spec.add_development_dependency "webmock"
  spec.add_development_dependency "simplecov"
  spec.add_development_dependency "allocation_stats"

  spec.add_runtime_dependency "json", ">= 1.8"
  spec.add_runtime_dependency "thread_safe", ">= 0.3"
  spec.add_runtime_dependency "concurrent-ruby", "~> 1.0"
  spec.add_runtime_dependency "faraday", ">= 0.8"
  spec.add_runtime_dependency "net-http-persistent", "~> 2.9"
  spec.add_runtime_dependency "redis", ">= 3.2"
end
