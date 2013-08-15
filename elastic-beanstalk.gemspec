# coding: utf-8
lib = File.expand_path('../lib', __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require 'elastic_beanstalk/version'

Gem::Specification.new do |spec|
  spec.name = 'elastic-beanstalk'
  spec.version = ElasticBeanstalk::VERSION
  spec.authors = ['Kevin Ross']
  spec.email = ['kevin.ross@alienfast.com']
  spec.description = %q{The simplest way to configure and deploy an Elastic Beanstalk application via rake.}
  spec.summary = %q{Configure and deploy a rails app to Elastic Beanstalk via rake in 60 seconds.  Maintain multiple environment DRY configurations and .ebextensions in one easy to use configuration file.}
  spec.homepage = 'https://github.com/alienfast/elastic-beanstalk'
  spec.license = 'MIT'

  spec.files = `git ls-files`.split($/).reject { |f| f =~ /^samples\// }
  spec.executables = spec.files.grep(%r{^bin/}) { |f| File.basename(f) }
  spec.test_files = spec.files.grep(%r{^(test|spec|features)/})
  spec.require_paths = %w(lib)

  spec.add_development_dependency 'bundler', '~> 1.3'
  spec.add_development_dependency 'rake'
  spec.add_development_dependency 'rspec', '>= 2.14.1'

  # spec.add_runtime_dependency
  spec.add_development_dependency 'rails' #, '>=3.2.13'
  spec.add_development_dependency 'eb_deployer'
  spec.add_development_dependency 'awesome_print'
  spec.add_development_dependency 'time_diff'
  spec.add_development_dependency 'zipruby'
  spec.add_development_dependency 'safe_yaml', '0.9.3'

end
