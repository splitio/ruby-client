guard :rspec, cmd: 'SPLITCLIENT_ENV=test bundle exec rspec' do
  watch(%r{^spec/.+_spec\.rb$})
  watch(%r{^lib/(.+)\.rb$}) { 'spec' }
end
