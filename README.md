# ElasticBeanstalk

Configure and deploy a rails app to Elastic Beanstalk via rake in 60 seconds.  Maintain multiple environment DRY configurations and .ebextensions in one easy to use configuration file.

This gem simplifies configuration, and passes the heavy lifting to ThoughtWorksStudios/eb_deployer.

## Installation

Add this line to your application's Gemfile:

    gem 'elastic-beanstalk'

And then execute:

    $ bundle

Or install it yourself as:

    $ gem install elastic-beanstalk

## Usage

Given an application named 'acme':

### Step 1: Add a ~/.aws.acme.yml
This should contain the access and secret keys generated from the selected IAM user.  This is the only file that will need to reside outside the repository.

    access_key_id: XXXXXX
    secret_access_key: XXXXXX

### Step 2.  Add a config/eb.yml to your rails project
Something like this should get you started
    ```yaml
    app: acme
    region: us-east-1
    solution_stack_name: 64bit Amazon Linux running Ruby 1.9.3

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
The default is the 'development' environment, change this via command line by prefixing with i.e. RAILS_ENV=production
    $ rake eb:package eb:deploy

### Step 4. Get some coffee
This will take a while.  We intend to provide an example in the wiki and/or samples dir that implements a [caching strategy detailed here](http://horewi.cz/faster-rails-3-deployments-to-aws-elastic-beanstalk.html) to speed up deployment.

## Rake Tasks

    eb:config #

## Contributing

Please contribute! While this is working great, a greater scope of functionality is certainly easily attainable with this foundation in place.

1. Fork it
2. Create your feature branch (`git checkout -b my-new-feature`)
3. Commit your changes (`git commit -am 'Add some feature'`)
4. Push to the branch (`git push origin my-new-feature`)
5. Create new Pull Request
