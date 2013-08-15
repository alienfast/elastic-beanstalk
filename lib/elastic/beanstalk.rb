module Elastic
  module Beanstalk
    require 'elastic/beanstalk/railtie' if defined?(Rails::Railtie)
    require 'deep_symbolize'
    require 'elastic/beanstalk/config'
    require 'elastic/beanstalk/extensions'
    require 'elastic/beanstalk/smoke_tester'
    require 'elastic/beanstalk/version'
  end
end

EbConfig = Elastic::Beanstalk::Config
EbExtensions = Elastic::Beanstalk::Extensions
EbSmokeTester = Elastic::Beanstalk::SmokeTester