module Elastic
  module Beanstalk
    require 'elastic/beanstalk/railtie' if defined?(Rails::Railtie)
    require 'deep_symbolize'
    require 'elastic/beanstalk/eb_config'
    require 'elastic/beanstalk/eb_extensions'
    require 'elastic/beanstalk/eb_smoke_tester'
    require 'elastic/beanstalk/version'
  end
end

EbConfig = Elastic::Beanstalk::EbConfig
EbExtensions = Elastic::Beanstalk::EbExtensions
EbSmokeTester = Elastic::Beanstalk::EbSmokeTester