require 'digest'
require 'zipruby' # gem 'zipruby'
require 'ap' # gem 'awesome_print'
require 'elastic/beanstalk/eb_config'
require 'elastic/beanstalk/eb_extensions'

namespace :eb do

  ###########################################
  #
  #
  #
  desc 'Setup AWS.config and merge/override environments into one resolved configuration'
  task :config do |t, args|

    # set the default environment to be development
    #env = ENV['RAILS_ENV'] || Rails.env || 'development'
    env = ENV['RAILS_ENV'] || 'development'

    # load the configuration
    EbConfig.load!(env)

    # Let's be explicit regardless of 'production' being the eb's default shall we? Set RACK_ENV and RAILS_ENV based on the given environment
    EbConfig.set_option(:'aws:elasticbeanstalk:application:environment', 'RACK_ENV', "#{EbConfig.environment}")
    EbConfig.set_option(:'aws:elasticbeanstalk:application:environment', 'RAILS_ENV', "#{EbConfig.environment}")

    # resolve the version and set the APP_VERSION environment variable
    resolve_version(args)

    # configure aws credentials
    AWS.config(credentials)

    # configure aws region if specified in the eb.yml
    AWS.config(region: EbConfig.region) unless EbConfig.region.nil?
  end

  ###########################################
  #
  #
  #
  desc 'Show resolved configuration without doing anything.'
  task :show_config, [:version] => [:config] do |t, args|


    puts "Working Directory: #{Rake.original_dir}"

    resolve_version(args)
    print_config
  end

  ###########################################
  #
  #
  #
  desc 'Remove any generated package.'
  task :clobber do |t, args|
    # kill the old package dir
    rm_r EbConfig.package[:dir] rescue nil
    #puts "Clobbered #{EbConfig.package[:dir]}."
  end

  ###########################################
  #
  # Elastic Beanstalk seems to be finicky with a tar.gz.  Using a zip, EB wants the files to be at the
  #   root of the archive, not under a top level folder.  Include this package task to make
  #   sure we don't need to learn about this again through long deploy cycles!
  #
  desc 'Package zip source bundle for Elastic Beanstalk'
  task :package => [:clobber, :config] do |t, args|

    begin
      # write .ebextensions
      EbExtensions.write_extensions

      # include all
      files = FileList[EbConfig.package[:includes]]

      # exclude files
      EbConfig.package[:exclude_files].each do |file|
        files.exclude(file)
      end

      EbConfig.package[:exclude_dirs].each do |dir|
        files.exclude("#{dir}/**/*")
        files.exclude("#{dir}")
      end

      # ensure dir exists
      mkdir_p EbConfig.package[:dir] rescue nil

      # zip it up
      Zip::Archive.open(package_file, Zip::CREATE) do |archive|

        puts "\nCreating archive (#{package_file}):" if package_verbose?
        files.each do |f|

          if File.directory?(f)
            puts "\t#{f}" if package_verbose?
            archive.add_dir(f)
          else
            puts "\t\t#{f}" if package_verbose?
            archive.add_file(f, f)
          end
        end
      end
      puts "\nFinished creating archive (#{package_file})."
    ensure
      EbExtensions.delete_extensions
    end
  end


  ###########################################
  #
  #
  #
  desc 'Deploy to Elastic Beanstalk'
  task :deploy, [:version] => [:config] do |t, args|
    # Leave off the dependency of :package, we need to package this in the build phase and save
    #   the artifact on bamboo. The deploy plan will handle this separately.
    from_time = Time.now

    # check package file
    raise "Package file not found (#{absolute_package_file}).  Be sure to run the :package task subsequent to any :deploy attempts." if !File.exists? absolute_package_file

    # Don't deploy to test or cucumber (or whatever is specified by :disallow_environments)
    raise "#{EbConfig.environment} is one of the #{EbConfig.disallow_environments} disallowed environments.  Configure it by changing the :disallow_environments in the eb.yml" if EbConfig.disallow_environments.include? EbConfig.environment

    # Use the version if given, otherwise use the MD5 hash.  Make available via the eb environment variable
    version = resolve_version(args)
    print_config

    # Avoid known problems
    if EbConfig.find_option_setting_value('InstanceType').nil?
      sleep 1 # let the puts from :config task finish first
      raise "Failure to set an InstanceType is known to cause problems with deployments (i.e. .aws-eb-startup-version error). Please set InstanceType in the eb.yml with something like:\n #{{options: {:'aws:autoscaling:launchconfiguration' => {InstanceType: 't1.micro'}}}.to_yaml}\n"
    end

    options = {
        application: EbConfig.app,
        environment: EbConfig.environment,
        version_label: version,
        solution_stack_name: EbConfig.solution_stack_name,
        settings: EbConfig.option_settings,
        strategy: EbConfig.strategy.to_sym,
        package: absolute_package_file
    }

    unless EbConfig.smoke_test.nil?
      options[:smoke_test] = eval EbConfig.smoke_test
    end

    EbDeployer.deploy(options)

    puts "\nDeployment finished in #{Time.diff(from_time, Time.now, '%N %S')[:diff]}.\n"
  end

  ###########################################
  #
  #
  #
  desc '** Warning: Destroy Elastic Beanstalk application and *all* environments.'
  task :destroy, [:force] do |t, args|

    if args[:force].eql? 'y'
      destroy()
    else
      puts 'Are you sure you wish to destroy application and *all* environments? (y/n)'
      input = STDIN.gets.strip
      if input == 'y'
        destroy()
      else
        puts 'Destroy canceled.'
      end
    end
  end

  ##########################################
  private

  # Use the version if given, otherwise use the MD5 hash.  Make available via the eb APP_VERSION environment variable
  def resolve_version(args)

    # if already set by a dependency call to :config, get out early
    version = EbConfig.find_option_setting_value('APP_VERSION')
    return version unless version.nil?

    # try to grab from task argument first
    version = args[:version]
    if version.nil? && File.exists?(absolute_package_file)
      # otherwise use the MD5 hash of the package file
      version = Digest::MD5.file(absolute_package_file).hexdigest
    end

    # set the var, depending on the sequence of calls, this may be nil
    #   (i.e. :show_config with no :version argument) so omit it until we have something worthwhile.
    EbConfig.set_option(:'aws:elasticbeanstalk:application:environment', 'APP_VERSION', "#{version}") unless version.nil?
  end

  def print_config
    # display helpful for figuring out problems later in the deployment logs.
    puts "\n----------------------------------------------------------------------------------"
    puts "Elastic Beanstalk configuration:"
    puts "\t:access_key_id: #{credentials['access_key_id']}"

    # pretty print things that will be useful to see in the deploy logs and omit clutter that usually doesn't cause us problems.
    h = EbConfig.configuration.dup
    h.delete(:package)
    h.delete(:disallow_environments)
    puts Hash[h.sort].deep_symbolize(true).to_yaml.gsub(/---\n/, "\n").gsub(/\n/, "\n\t")
    puts "----------------------------------------------------------------------------------\n"
  end

  def destroy
    Rake::Task['eb:config'].invoke
    EbDeployer.destroy(application: EbConfig.app)
    puts "Destroy issued to AWS."
  end

  # load from a user directory i.e. ~/.aws.acme.yml
  def credentials

    raise "Failed to load AWS secrets: #{aws_secrets_file}.\nFile contents should look like:\naccess_key_id: XXXX\nsecret_access_key: XXXX" unless File.exists?(aws_secrets_file)

    # load secrets from the user home directory
    @credentials = YAML.safe_load_file(aws_secrets_file) if @credentials.nil?
    @credentials
  end

  def package_verbose?
    EbConfig.package[:verbose] || false
  end

  def package_file
    "#{EbConfig.package[:dir]}/#{EbConfig.app}.zip"
  end

  def aws_secrets_file
    File.expand_path("~/.aws.#{EbConfig.app}.yml")
  end

  def absolute_package_file
    filename = package_file()
    unless filename.start_with? '/'
      filename = filename.gsub('[', '').gsub(']', '')
      filename = EbConfig.resolve_path(filename)
    end
    filename
  end
end