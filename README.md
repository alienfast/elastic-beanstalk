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

```ruby
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
```

### Step 3. Package and deploy
The default is the 'development' environment, change this via command line arguments

    $ rake eb:package eb:deploy

### Step 4. Get some coffee
This will take a while.  We intend to provide an example in the wiki and/or samples dir that implements a [caching strategy detailed here](http://horewi.cz/faster-rails-3-deployments-to-aws-elastic-beanstalk.html) to speed up deployment.

## Rake Tasks

### EB

    rake eb:clobber                             # Remove any generated package
    rake eb:config[environment,version]         # Setup AWS.config and merge/override environments into one resolved configuration
    rake eb:deploy[environment,version]         # Deploy to Elastic Beanstalk
    rake eb:destroy[force]                      # ** Warning: Destroy Elastic Beanstalk application and *all* environments
    rake eb:package[environment,version]        # Package zip source bundle for Elastic Beanstalk
    rake eb:show_config[environment,version]    # Show resolved configuration without doing anything

### EB:RDS Rake Tasks

The EB:RDS tasks are intended to make use of RDS tasks simple given existing configuration in the eb.yml.
i.e. create a snapshot before or after an `eb:deploy`.  The following rake tasks exist:

    rake eb:rds:create_snapshot[instance_id,snapshot_id]   # Creates an RDS snapshot
    rake eb:rds:instances                                  # List RDS instances
    rake eb:rds:snapshots                                  # List RDS snapshots

For example, this would create a snapshot prior to the deployment (and migration) to version 1.1.0:

    rake eb:rds:create_snapshot[acme, pre-1.1.0] eb:deploy[1.1.0]

### Using RAILS_ENV vs :environment:  
Some people prefer to use `RAILS_ENV`, others prefer to use the `:environment` argument.  Both are accepted. Depending on the use case, each one can be DRYer than the other. 
Where the task specifies `[:environment, :version]`, consider the `:environment` optional if you want to use the default of `development` or utilize the `RAILS_ENV` instead.  

**NOTE:** if using the argument `:environment`, you **must** specify it for **both** the `eb:package` and `eb:deploy`, as `eb:package` is responsible for injecting the `RACK_ENV` and `RAILS_ENV` 
in `aws:elasticbeanstalk:application:environment` section of the `.ebextensions` file.
     
### :version 
If not specified, version will be auto-generated via and MD5 hash of the package file. If specified to the `eb:package` task, the version will be available as the `APP_VERSION` 
environment variable, specified in the `aws:elasticbeanstalk:application:environment` section of the `.ebextensions` file.  


## A real-world example

Deploy version 1.1.3 of acme to production using the `:environment` parameter

    $ rake eb:package[production,1.1.3] eb:deploy[production,1.1.3]

Deploy version 1.1.3 of acme to production using `RAILS_ENV`

    $ RAILS_ENV=production rake eb:package[1.1.3] eb:deploy[1.1.3]
    
Deploy an MD5 hashed version of acme to production using the `:environment` parameter

    $ rake eb:package[production] eb:deploy[production]

Deploy an MD5 hashed version of acme to production using `RAILS_ENV`

    $ RAILS_ENV=production rake eb:package eb:deploy
    
Deploy an MD5 hashed version of acme to development

    $ rake eb:package eb:deploy
        

config/eb.yml

```ruby
# This is a sample that has not been executed so it may not be exactly 100%, but is intended to show
#   that access to full options_settings and .ebextensions is intended.
#---
# http://docs.aws.amazon.com/elasticbeanstalk/latest/dg/command-options.html#command-options-ruby
#
# This is a sample that has not been executed so it may not be exactly 100%, but is intended to show
#   that access to full options_settings and .ebextensions is intended.
#---
app: acme
region: us-east-1
# Choose a platform from http://docs.aws.amazon.com/elasticbeanstalk/latest/dg/concepts.platforms.html
solution_stack_name: 64bit Amazon Linux 2015.03 v2.0.0 running Ruby 2.2 (Passenger Standalone)
strategy: inplace-update # default to inplace-update to avoid starting new environments
package:
  verbose: true
  exclude_dirs: [features, spec, target, coverage, vcr, flows]  # additional dirs that merge with default excludes
  exclude_files: [.ruby-*,  rspec.xml, README*, db/*.sqlite3, bower.json]
smoke_test: |
    lambda { |host|
      EbSmokeTester.test_url("http://#{host}/health", 600, 5, 'All good! Everything is up and checks out.')
    }
#--
ebextensions:
  # General settings for the server environment
  01-environment.config:
    commands:
      01timezone:
        command: "ln -sf /usr/share/zoneinfo/America/Chicago /etc/localtime"

  # These are things that make sense for any Ruby application
  02-ruby.config:
    # Install git in order to be able to bundle gems from git
    packages:
      yum:
        git: []
        patch: []

  # Run rake tasks before an application deployment
  03-rake.config:
    container_commands:
      01seed:
        command: rake db:seed
        leader_only: true

#---
options:

  # Any environment variables - will be available in ENV
  aws:elasticbeanstalk:application:environment:
    FOO: 'bar'

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
    Application Healthcheck URL: '/health'
#---
development:
  options:
    aws:autoscaling:launchconfiguration:
      InstanceType: t1.micro
    aws:elasticbeanstalk:application:environment:
      RAILS_SKIP_ASSET_COMPILATION: true
#---
production:
  strategy: blue-green # always fire up a new environment and healthcheck before transitioning cname
  options:
    aws:autoscaling:launchconfiguration:
      InstanceType: t1.small
```

## Additional options
Most of the configurations are defaulted.  The following are less obvious but may be useful:

```ruby
secrets_dir: (default: '~/.aws')
package:
  verbose: (default: false)
  dir: (default: 'pkg')
```

### eb_deployer additional options
The following are passed if not nil, otherwise eb_deployer assigns an appropriate default.

```ruby
package_bucket:
keep_latest:
version_prefix:
tier:
```

## Still to come
1. Caching sample config?
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
