# ElasticBeanstalk

Configure and deploy a rails app to Elastic Beanstalk via rake in 60 seconds.  Maintain multiple environment DRY configurations and .ebextensions in one easy to use yaml configuration file.

This gem simplifies configuration, and passes the heavy lifting to the [eb_deployer](https://github.com/ThoughtWorksStudios/eb_deployer) from ThoughtWorksStudios.

## Installation

Add this line to your application's Gemfile:

    gem 'elastic-beanstalk'

And then execute:

    $ bundle

Or install it yourself as:

    $ gem install elastic-beanstalk

## Features

### The elastic-beanstalk gem provides:
* Rake tasks to simplify all interactions
* Multi-environment configuration inheritance for DRY yaml configs
* Keep all configurations including .ebextensions in one yaml file (they are inheritable and can be overridden too)
* Full access to the range of configuration options provided by AWS Elastic Beanstalk
* Provide access to helpers such as the SmokeTester to simplify configurations

### Plus
Since [eb_deployer](https://github.com/ThoughtWorksStudios/eb_deployer) is doing the heavy lifting, by proxy you get access to great continuous delivery features such as:
* Blue Green deployment strategy
* In Place deployment strategy
* Smoke Testing upon deployment before Blue Green DNS switching

## Usage

Given an application named 'acme':

### Step 1: Add ~/.aws/acme.yml
This should contain the access and secret keys generated from the selected IAM user.  This is the only file that will need to reside outside the repository.  Note that this location is configurable in the `config/eb.yml` file.

    access_key_id: XXXXXX
    secret_access_key: XXXXXX

### Step 2.  Add a config/eb.yml to your rails project
Something like this should get you started

    app: acme
    region: us-east-1
    # http://docs.aws.amazon.com/elasticbeanstalk/latest/dg/concepts.platforms.html
    solution_stack_name: 64bit Amazon Linux 2013.09 running Ruby 1.9.3

    development:
      strategy: inplace_update
      options:
        aws:autoscaling:launchconfiguration:
          InstanceType: t1.micro

    production:
      options:
        aws:autoscaling:launchconfiguration:
          InstanceType: t1.small

### Step 3. Package and deploy
The default is the 'development' environment, change this via command line by prefixing with i.e. RAILS_ENV=production

    $ rake eb:package eb:deploy

### Step 4. Get some coffee
This will take a while.  We intend to provide an example in the wiki and/or samples dir that implements a [caching strategy detailed here](http://horewi.cz/faster-rails-3-deployments-to-aws-elastic-beanstalk.html) to speed up deployment.

## EB Rake Tasks

    rake eb:clobber                 # Remove any generated package
    rake eb:config                  # Setup AWS.config and merge/override environments into one resolved configuration
    rake eb:deploy[version]         # Deploy to Elastic Beanstalk
    rake eb:destroy[force]          # ** Warning: Destroy Elastic Beanstalk application and *all* environments
    rake eb:package                 # Package zip source bundle for Elastic Beanstalk
    rake eb:show_config[version]    # Show resolved configuration without doing anything

## EB:RDS Rake Tasks

The EB:RDS tasks are intended to make use of RDS tasks simple given existing configuration in the eb.yml.
i.e. create a snapshot before or after an `eb:deploy`.  The following rake tasks exist:

    rake eb:rds:create_snapshot[instance_id,snapshot_id]   # Creates an RDS snapshot
    rake eb:rds:instances                                  # List RDS instances
    rake eb:rds:snapshots                                  # List RDS snapshots

For example, this would create a snapshot prior to the deployment (and migration) to version 1.1.0:

    rake eb:rds:create_snapshot[acme, pre-1.1.0] eb:deploy[1.1.0]

## A real-world example

Deploy version 1.1.3 of acme to production

    $ RAILS_ENV=production rake eb:package eb:deploy[1.1.3]

config/eb.yml

    # This is a sample that has not been executed so it may not be exactly 100%, but is intended to show
    #   that access to full options_settings and .ebextensions is intended.
    #---
    app: acme
    region: us-east-1
    solution_stack_name: 64bit Amazon Linux running Ruby 1.9.3
    package:
      verbose: true
      exclude_dirs: [solr, features] # additional dirs that merge with default excludes
      exclude_files: [rspec.xml, README*, db/*.sqlite3]
    smoke_test: |
        lambda { |host|

          EbSmokeTester.test_url("http://#{host}/ping", 600, 5, 'All good! Everything is up and checks out.')
        }
    #--
    ebextensions:
      01settings.config:
        # Run rake tasks before an application deployment
        container_commands:
          01seed:
            command: rake db:seed
            leader_only: true
      # run any necessary commands
      02commands.config:
        container_commands:
          01timezone:
            command: "ln -sf /usr/share/zoneinfo/America/Chicago /etc/localtime"

      # These are things that make sense for any Ruby application see:
      #     https://github.com/gkop/elastic-beanstalk-ruby/blob/master/.ebextensions/ruby.config
      03-ruby.config:

        # Install git in order to be able to bundle gems from git
        packages:
          yum:
            git: []
        commands:
          # Run rake with bundle exec to be sure you get the right version
          add_bundle_exec:
            test: test ! -f /opt/elasticbeanstalk/support/.post-provisioning-complete
            cwd: /opt/elasticbeanstalk/hooks/appdeploy/pre
            command: perl -pi -e 's/(rake)/bundle exec $1/' 11_asset_compilation.sh 12_db_migration.sh
          # Bundle with --deployment as recommended by bundler docs
          #   cf. http://gembundler.com/v1.2/rationale.html under Deploying Your Application
          add_deployment_flag:
            test: test ! -f /opt/elasticbeanstalk/support/.post-provisioning-complete
            cwd: /opt/elasticbeanstalk/hooks/appdeploy/pre
            command: perl -pi -e 's/(bundle install)/$1 --deployment/' 10_bundle_install.sh
          # Vendor gems to a persistent directory for speedy subsequent bundling
          make_vendor_bundle_dir:
            test: test ! -f /opt/elasticbeanstalk/support/.post-provisioning-complete
            command: mkdir /var/app/support/vendor_bundle
          # Store the location of vendored gems in a handy env var
          set_vendor_bundle_var:
            test: test ! -f /opt/elasticbeanstalk/support/.post-provisioning-complete
            cwd: /opt/elasticbeanstalk/support
            command: sed -i '12iexport EB_CONFIG_APP_VENDOR_BUNDLE=$EB_CONFIG_APP_SUPPORT/vendor_bundle' envvars
          # The --deployment flag tells bundler to install gems to vendor/bundle/, so
          # symlink that to the persistent directory
          symlink_vendor_bundle:
            test: test ! -f /opt/elasticbeanstalk/support/.post-provisioning-complete
            cwd: /opt/elasticbeanstalk/hooks/appdeploy/pre
            command: sed -i '6iln -s $EB_CONFIG_APP_VENDOR_BUNDLE ./vendor/bundle' 10_bundle_install.sh
          # Don't run the above commands again on this instance
          #   cf. http://stackoverflow.com/a/16846429/283398
          z_write_post_provisioning_complete_file:
            cwd: /opt/elasticbeanstalk/support
            command: touch .post-provisioning-complete
    #---
    options:
      aws:autoscaling:launchconfiguration:
        EC2KeyName: eb-ssh
        SecurityGroups: 'acme-production-control'

      aws:autoscaling:asg:
        MinSize: 1
        MaxSize: 5

      aws:elb:loadbalancer:
        SSLCertificateId: 'arn:aws:iam::XXXXXXX:server-certificate/acme'
        LoadBalancerHTTPSPort: 443

      aws:elb:policies:
        Stickiness Policy: true

      aws:elasticbeanstalk:sns:topics:
        Notification Endpoint: 'alerts@acme.com'

      aws:elasticbeanstalk:application:
        Application Healthcheck URL: '/'
    #---
    development:
      strategy: inplace_update
      options:
        aws:autoscaling:launchconfiguration:
          InstanceType: t1.micro
        aws:elasticbeanstalk:application:environment:
          RAILS_SKIP_ASSET_COMPILATION: true
    #---
    production:
      options:
        aws:autoscaling:launchconfiguration:
          InstanceType: t1.small


## Additional options
Most of the configurations are defaulted.  The following are less obvious but may be useful:

    secrets_dir: (default: '~/.aws')
    package:
      verbose: (default: false)
      dir: (default: 'pkg')

### eb_deployer additional options
The following are passed if not nil, otherwise eb_deployer assigns an appropriate default.

    package_bucket:
    keep_latest:
    version_prefix:

## Still to come
1. Caching sample config
2. More thorough access to the Elastic Beanstalk api as-needed.

## Contributing

Please contribute! While this is working great, a greater scope of functionality is certainly easily attainable with this foundation in place.

1. Fork it
2. Create your feature branch (`git checkout -b my-new-feature`)
3. Commit your changes (`git commit -am 'Add some feature'`)
4. Push to the branch (`git push origin my-new-feature`)
5. Create new Pull Request

## Copyright

Copyright (c) 2014 AlienFast, LLC. See LICENSE.txt for further details.
