require 'deep_symbolize'
require 'elastic_beanstalk/eb_config'
require 'elastic_beanstalk/eb_extensions'
require 'elastic_beanstalk/eb_smoke_tester'
require 'elastic_beanstalk/railtie' #if defined?(Rails)
require 'elastic_beanstalk/version'

module ElasticBeanstalk
end

EbConfig = ElasticBeanstalk::EbConfig
EbExtensions = ElasticBeanstalk::EbExtensions
EbSmokeTester = ElasticBeanstalk::EbSmokeTester