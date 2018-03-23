require 'bundler/gem_tasks'
require 'rspec/core/rake_task'

Dir['tasks/**/*.rake'].each { |rake| load rake }

RSpec::Core::RakeTask.new(:spec)

task :spec => :compile
case RUBY_PLATFORM
when 'java'
  require 'rake/javaextensiontask'
  Rake::JavaExtensionTask.new 'murmurhash' do |ext|
    ext.lib_dir = 'lib/murmurhash'
    ext.target_version = '1.7'
    ext.source_version = '1.7'
  end
else
  require 'rake/extensiontask'
  Rake::ExtensionTask.new 'murmurhash' do |ext|
    ext.lib_dir = 'lib/murmurhash'
  end
end

task :default => :spec
