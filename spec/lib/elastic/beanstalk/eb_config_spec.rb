require 'spec_helper'

describe EbConfig do
  # not sure why, but clear appears to unreliably run before each test.  Sometimes does, sometimes doesn't.
  #before do
  #  EbConfig.clear
  #  puts 'clear'
  #end

  before(:each) do
     EbConfig.clear
  end

  it '#set_option' do
    EbConfig.set_option('aws:elasticbeanstalk:application:environment', 'RACK_ENV', 'staging')
    expect(EbConfig.options[:'aws:elasticbeanstalk:application:environment'][:'RACK_ENV']).to eq 'staging'
  end

  it '#find_option_setting_value' do
    EbConfig.set_option(:'aws:elasticbeanstalk:application:environment', 'RACK_ENV', 'staging')
    expect(EbConfig.find_option_setting_value('RACK_ENV')).to eql 'staging'
  end
  it '#find_option_setting' do
    EbConfig.set_option(:'aws:elasticbeanstalk:application:environment', 'RACK_ENV', 'staging')
    expect(EbConfig.find_option_setting('RACK_ENV')).to eql ({:namespace => 'aws:elasticbeanstalk:application:environment', :option_name => 'RACK_ENV', :value => 'staging'})
  end

  it '#set_option should allow options to be overridden' do
    EbConfig.set_option(:'aws:elasticbeanstalk:application:environment', 'RACK_ENV', 'staging')
    assert_option 'RACK_ENV', 'staging'
    EbConfig.set_option(:'aws:elasticbeanstalk:application:environment', 'RACK_ENV', 'foo')
    assert_option 'RACK_ENV', 'foo'
  end

  it '#set_option should work with strings or deep symbols' do
    option_input = [ :'aws:elasticbeanstalk:application:environment', :'RACK_ENV', :TEST_VALUE ]
    method_order = [:to_sym, :to_s, :to_sym]
    method_order.each do |current_method|
      option_input.map!(&current_method)
      EbConfig.clear
      EbConfig.set_option(*option_input)
      assert_option option_input[1].to_s, option_input[2].to_s
    end
  end

  it '#set_option should work with environment variable interpolation' do
    ENV['test_value'] = 'foo'
    EbConfig.set_option(:'aws:elasticbeanstalk:application:environment', 'TEST_VAR', '<%= ENV["test_value"] %>')
    assert_option 'TEST_VAR', 'foo'
  end

  it 'should read file with nil environment' do
    sleep 1
    #expect(EbConfig.strategy).to be_nil

    EbConfig.load!(nil, config_file_path)
    assert_common_top_level_settings()
    assert_option 'InstanceType', 'foo'
    #expect(EbConfig.strategy).to be_nil
    expect(EbConfig.environment).to be_nil
  end

  it 'should read file and override with development environment' do
    EbConfig.load!(:development, config_file_path)
    assert_option 'InstanceType', 't1.micro'
    expect(EbConfig.strategy).to eql 'inplace-update'
    expect(EbConfig.environment).to eql :development
  end

  it 'should read file and override with production environment' do
    EbConfig.load!(:production, config_file_path)
    assert_option 'InstanceType', 't1.small'
    expect(EbConfig.environment).to eql :production
  end

  private
  def assert_option(name, value)
    expect(EbConfig.find_option_setting_value(name)).to eql value
  end

  def assert_inactive(name, value)
    expect(EbConfig.find_inactive_setting_value(name)).to eql value
  end

  def assert_common_top_level_settings
    expect(EbConfig.app).to eql 'acme'
    expect(EbConfig.region).to eql 'us-east-1'
    expect(EbConfig.secrets_dir).to eql '~/.aws'
    expect(EbConfig.strategy).to eql :blue_green
    expect(EbConfig.solution_stack_name).to eql '64bit Amazon Linux running Ruby 1.9.3'
    expect(EbConfig.disallow_environments).to eql %w(cucumber test)

    expect(EbConfig.package[:dir]).to eql 'pkg'
    expect(EbConfig.package[:verbose]).to be_truthy
    expect(EbConfig.package[:includes]).to eql %w(**/* .ebextensions/**/*)
    expect(EbConfig.package[:exclude_files]).to eql %w(resetdb.sh rspec.xml README* db/*.sqlite3)
    expect(EbConfig.package[:exclude_dirs]).to eql %w(pkg tmp log test-reports solr features)

    # assert set_option new
    EbConfig.set_option(:'aws:elasticbeanstalk:application:environment', 'RACK_ENV', 'staging')
    assert_option 'RACK_ENV', 'staging'

    # assert set_option overwrite
    EbConfig.set_option(:'aws:elasticbeanstalk:application:environment', 'RAILS_ENV', 'staging')
    assert_option 'RAILS_ENV', 'staging'

    assert_option 'EC2KeyName', 'eb-ssh'

    assert_option 'SecurityGroups', 'acme-production-control'
    assert_option 'MinSize', '1'
    assert_option 'MaxSize', '5'
    assert_option 'SSLCertificateId', 'arn:aws:iam::XXXXXXX:server-certificate/acme'
    assert_option 'LoadBalancerHTTPSPort', '443'
    assert_option 'Stickiness Policy', 'true'
    assert_option 'Notification Endpoint', 'alerts@acme.com'
    assert_option 'Application Healthcheck URL', '/healthcheck'

    assert_inactive 'MinSize', '0'
    assert_inactive 'Cooldown', '900'
  end

  def config_file_path
    File.expand_path('../eb_spec.yml', __FILE__)
  end
end