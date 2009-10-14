# -*- ruby -*-

require 'rubygems'
require './lib/cloud_cache.rb'


begin
    require 'jeweler'
    Jeweler::Tasks.new do |gemspec|
        gemspec.name = "cloud_cache"
        gemspec.summary = "Client library for Quetzall's CloudCache service."
        gemspec.email = "travis@appoxy.com"
        gemspec.homepage = "http://github.com/quetzall/cloud_cache/"
        gemspec.description = "Client library for Quetzall's CloudCache service."
        gemspec.authors = ["Travis Reeder"]
        gemspec.files = FileList['lib/**/*.rb']
        gemspec.add_dependency 'http_connection'
    end
rescue LoadError
    puts "Jeweler not available. Install it with: sudo gem install technicalpickles-jeweler -s http://gems.github.com"
end

# vim: syntax=Ruby
task :test do
    Dir.chdir 'test'
#    require 'lib/cloud_cache'
    require 'cache_tests'
end
