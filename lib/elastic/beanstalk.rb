module Elastic
  module Beanstalk
    require 'elastic/beanstalk/railtie' if defined?(Rails::Railtie)
    require 'elastic/beanstalk/config'
    require 'elastic/beanstalk/extensions'
    require 'elastic/beanstalk/smoke_tester'
    require 'elastic/beanstalk/version'
    require 'elastic/beanstalk/spinner'
  end
end

EbConfig = Elastic::Beanstalk::Config.instance
EbExtensions = Elastic::Beanstalk::Extensions
EbSmokeTester = Elastic::Beanstalk::SmokeTester
Spinner = Elastic::Beanstalk::Spinner
