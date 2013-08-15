require 'elastic_beanstalk'
require 'rails'

module ElasticBeanstalk
  class Railtie < Rails::Railtie
    railtie_name :elastic_beanstalk

    rake_tasks do
      load '/lib/tasks/eb.rake'
    end
  end
end