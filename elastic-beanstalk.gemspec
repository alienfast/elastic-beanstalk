# coding: utf-8
lib = File.expand_path('../lib', __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require 'elastic/beanstalk/version'

Gem::Specification.new do |spec|
  spec.name = 'elastic-beanstalk'
  spec.version = Elastic::Beanstalk::VERSION
  spec.authors = ['Kevin Ross']
  spec.email = ['kevin.ross@alienfast.com']
  spec.description = <<-TEXT
    The simplest way to configure and deploy an Elastic Beanstalk application via rake.
  TEXT
  spec.summary = <<-TEXT
    Configure and deploy a rails app to Elastic Beanstalk via rake in 60 seconds.
    Maintain multiple environment DRY configurations and .ebextensions in one easy
    to use configuration file.
  TEXT
  spec.homepage = 'https://github.com/alienfast/elastic-beanstalk'
  spec.license = 'MIT'

  spec.files = `git ls-files`.split($/).reject { |f| f =~ /^samples\// }
  spec.executables = spec.files.grep(%r{^bin/}) { |f| File.basename(f) }
  spec.test_files = spec.files.grep(%r{^(test|spec|features)/})
  spec.require_paths = ['lib']

  # development
  spec.add_development_dependency 'bundler', '~> 1.3'
  spec.add_development_dependency 'rake'
  spec.add_development_dependency 'rspec', '>= 2.14.1'

  # runtime
  spec.add_runtime_dependency 'railties', '>= 3.2'
  spec.add_runtime_dependency 'eb_deployer'
  spec.add_runtime_dependency 'awesome_print'
  spec.add_runtime_dependency 'time_diff'
  spec.add_runtime_dependency 'zipruby'
  spec.add_runtime_dependency 'table_print'
  spec.add_runtime_dependency 'nokogiri'
end
