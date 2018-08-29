# frozen_string_literal: true

desc 'Open an irb session preloaded with this library'
task :irb do
  sh 'irb -rubygems -I lib -r splitclient-rb.rb'
end
