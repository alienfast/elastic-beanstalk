require 'spec_helper'
require 'rake'

# The `credentials` method is called against the main ruby object.
# We maintain a reference to it so that we can avoid setting real credentials in the test.
# This test reaches in to set the @credentials ivar instead of stubbing a method because
# reliably stubbing and unstubbing a global object is error prone and would affect other tests.
$main = self

describe 'eb namespace rake task' do
  describe 'eb:config' do
    before do
      load 'lib/elastic/beanstalk/tasks/eb.rake'
      Rake::Task.define_task(:environment)
      $main.instance_variable_set(:@credentials, {})
      allow(EbConfig).to receive(:resolve_path).and_return('spec/lib/elastic/beanstalk/eb_spec.yml')
      # We could run eb:show_config, but it is easier to access the data directly
      Rake::Task['eb:config'].invoke('staging')
    end

    after do
      $main.remove_instance_variable(:@credentials)
    end

    it 'should not override the RAILS_ENV in eb.yml' do
      rails_env = EbConfig.configuration.fetch(:options, {})
                                        .fetch(:'aws:elasticbeanstalk:application:environment', {})
                                        .fetch(:RAILS_ENV, nil)
      expect(rails_env).to eq('foobar')
    end

    it 'should not override the RACK_ENV in eb.yml' do
      rack_env = EbConfig.configuration.fetch(:options, {})
                                       .fetch(:'aws:elasticbeanstalk:application:environment', {})
                                       .fetch(:RACK_ENV, nil)
      expect(rack_env).to eq('bizbaz')
    end
  end
end
