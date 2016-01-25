# coding: utf-8
lib = File.expand_path('../lib', __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require 'splitclient-rb/version'

Gem::Specification.new do |spec|
  spec.name          = "splitclient-rb"
  spec.version       = SplitIoClient::VERSION
  spec.authors       = ["Split Software"]
  spec.email         = ["Split Software"]

  spec.summary       = %q{Ruby client for split SDK.}
  spec.description   = %q{Ruby client for using split SDK.}
  spec.homepage      = "https://sdk.split.io"
  spec.license       = "Apache"

  # Prevent pushing this gem to RubyGems.org by setting 'allowed_push_host', or
  # delete this section to allow pushing this gem to any host.
  if spec.respond_to?(:metadata)
    spec.metadata['allowed_push_host'] = "TODO: Set to 'http://mygemserver.com'"
  else
    raise "RubyGems 2.0 or newer is required to protect against public gem pushes."
  end

  spec.files         = `git ls-files -z`.split("\x0").reject { |f| f.match(%r{^(test|spec|features)/}) }
  spec.bindir        = "exe"
  spec.executables   = spec.files.grep(%r{^exe/}) { |f| File.basename(f) }
  spec.require_paths = ["lib"]

  spec.add_development_dependency "bundler", "~> 1.11"
  spec.add_development_dependency "rake", "~> 10.0"
  spec.add_development_dependency "rspec"
  spec.add_development_dependency "simplecov"

  spec.add_runtime_dependency "json", "~> 1.8"
  spec.add_runtime_dependency "thread_safe"
  spec.add_runtime_dependency "concurrent-ruby"
  spec.add_runtime_dependency "faraday"
  spec.add_runtime_dependency "faraday-http-cache"
  spec.add_runtime_dependency "net-http-persistent"
end
