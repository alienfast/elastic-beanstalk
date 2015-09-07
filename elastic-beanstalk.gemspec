# coding: utf-8
lib = File.expand_path('../lib', __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require 'elastic/beanstalk/version'

Gem::Specification.new do |s|
  s.name = 'elastic-beanstalk'
  s.version = Elastic::Beanstalk::VERSION
  s.authors = ['Kevin Ross']
  s.email = ['kevin.ross@alienfast.com']
  s.description = <<-TEXT
    The simplest way to configure and deploy an Elastic Beanstalk application via rake.
  TEXT
  s.summary = <<-TEXT
    Configure and deploy a rails app to Elastic Beanstalk via rake in 60 seconds.
    Maintain multiple environment DRY configurations and .ebextensions in one easy
    to use configuration file.
  TEXT
  s.homepage = 'https://github.com/alienfast/elastic-beanstalk'
  s.license = 'MIT'

  s.files = `git ls-files`.split($/).reject { |f| f =~ /^samples\// }
  s.executables = s.files.grep(%r{^bin/}) { |f| File.basename(f) }
  s.test_files = s.files.grep(%r{^(test|spec|features)/})
  s.require_paths = ['lib']

  # development
  s.add_development_dependency 'bundler'
  s.add_development_dependency 'rake'
  s.add_development_dependency 'rspec'
  s.add_development_dependency 'rspec_junit_formatter'

  # runtime
  s.add_runtime_dependency 'railties', '>= 3.2'
  s.add_runtime_dependency 'eb_deployer', '>= 0.6.1'
  s.add_runtime_dependency 'awesome_print'
  s.add_runtime_dependency 'time_diff'
  s.add_runtime_dependency 'rubyzip'
  s.add_runtime_dependency 'table_print'
  s.add_runtime_dependency 'nokogiri'
  s.add_runtime_dependency 'dry-config', '>=1.1.4'
end
