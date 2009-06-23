# -*- ruby -*-

require 'rubygems'
require 'hoe'
require './lib/cloud_cache.rb'

#Hoe.new('cloud_cache', ActiveSupport::Cache::CloudCache::VERSION) do |p|
#  p.rubyforge_name = 'spacegems' # if different than lowercase project name
#  p.developer('Travis Reeder', 'travis@appoxy.com')
#end


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
    end
rescue LoadError
    puts "Jeweler not available. Install it with: sudo gem install technicalpickles-jeweler -s http://gems.github.com"
end

# vim: syntax=Ruby
