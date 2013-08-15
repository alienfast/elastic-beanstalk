#require 'beanstalk'
#require 'rails'

module Elastic
  module Beanstalk

    # https://gist.github.com/josevalim/af7e572c2dc973add221
    class Railtie < Rails::Railtie

      #railtie_name :elastic

      rake_tasks do
        load 'elastic/beanstalk/tasks/eb.rake'
      end
    end
  end
end