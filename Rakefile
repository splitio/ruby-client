require 'bundler/gem_tasks'
require 'rake/extensiontask'
require 'rake/javaextensiontask'
require 'rspec/core/rake_task'

Dir['tasks/**/*.rake'].each { |rake| load rake }

RSpec::Core::RakeTask.new(:spec)

task :spec => :compile

Rake::ExtensionTask.new 'murmurhash' do |ext|
  ext.lib_dir = 'lib/murmurhash'
end
# Rake::JavaExtensionTask.new('ext')

task :default => :spec
