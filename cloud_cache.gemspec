# -*- encoding: utf-8 -*-

Gem::Specification.new do |s|
  s.name = %q{cloud_cache}
  s.version = "1.2.2"

  s.required_rubygems_version = Gem::Requirement.new(">= 0") if s.respond_to? :required_rubygems_version=
  s.authors = ["Travis Reeder"]
  s.date = %q{2009-09-14}
  s.description = %q{Client library for Quetzall's CloudCache service.}
  s.email = %q{travis@appoxy.com}
  s.extra_rdoc_files = [
    "README.txt"
  ]
  s.files = [
    "lib/cloud_cache.rb",
     "lib/hmac-sha1.rb",
     "lib/hmac.rb"
  ]
  s.has_rdoc = true
  s.homepage = %q{http://github.com/quetzall/cloud_cache/}
  s.rdoc_options = ["--charset=UTF-8"]
  s.require_paths = ["lib"]
  s.rubygems_version = %q{1.3.1}
  s.summary = %q{Client library for Quetzall's CloudCache service.}
  s.test_files = [
    "test/cache_tests.rb",
     "test/my_class.rb",
     "test/test_cloud_cache.rb",
     "test/test_runner.rb"
  ]

  if s.respond_to? :specification_version then
    current_version = Gem::Specification::CURRENT_SPECIFICATION_VERSION
    s.specification_version = 2

    if Gem::Version.new(Gem::RubyGemsVersion) >= Gem::Version.new('1.2.0') then
    else
    end
  else
  end
end
