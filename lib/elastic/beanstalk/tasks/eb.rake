require 'digest'
require 'zip'
require 'ap' # gem 'awesome_print'
require 'eb_deployer'
require 'time_diff'
require 'elastic/beanstalk'
require 'yaml'
require 'table_print'
require 'timeout'

namespace :eb do

  namespace :rds do
    # http://docs.aws.amazon.com/AWSRubySDK/latest/frames.html
    desc 'List RDS snapshots'
    task :snapshots => [:config] do |t, args|
      # absolutely do not run this without specifying columns, otherwise it will call all defined methods including :delete
      print_snapshots(rds.snapshots.to_a)
    end

    desc 'List RDS instances'
    task :instances => [:config] do |t, args|
      # absolutely do not run this without specifying columns, otherwise it will call all defined methods including :delete
      print_instances(rds.instances.to_a)
    end

    desc 'Creates an RDS snapshot'
    task :create_snapshot, [:instance_id, :snapshot_id] => [:config] do |t, args|

      snapshot_id = args[:snapshot_id]

      db = db(args[:instance_id])

      from_time = Time.now
      puts "\n\n---------------------------------------------------------------------------------------------------------------------------------------"
      snapshot = db.create_snapshot(snapshot_id)
      #snapshot = snapshot(snapshot_id) # for quick testing of code below


      #ID    | STATUS   | GB | TYPE   | ENGINE       | ZONE       | CREATED_AT | INSTANCE_CREATE_TIME
      #------|----------|----|--------|--------------|------------|------------|------------------------
      #pre-2 | creating | 10 | manual | mysql 5.6.12 | us-east-1d |            | 2013-09-10 21:37:27
      #        available
      print_snapshots(snapshot)
      puts "\n"

      timeout = 20 * 60
      sleep_wait = 5
      begin
        Timeout.timeout(timeout) do
          i = 0

          print "\nCreating snapshot[#{snapshot_id}]..."
          Spinner.show {
            begin
              sleep sleep_wait.to_i unless (i == 0)
              i += 1

              snapshot = snapshot(snapshot_id)

            end until (snapshot.status.eql? 'available')
          }
        end
      ensure
        puts "\n\nSnapshot[#{snapshot_id}]: #{snapshot.status}. Finished in #{Time.diff(from_time, Time.now, '%N %S')[:diff]}.\n"
        puts "---------------------------------------------------------------------------------------------------------------------------------------\n\n"
      end
    end

    def snapshot(snapshot_id)
      AWS::RDS::DBSnapshot.new(snapshot_id)
    end

    def db(instance_id)
      db_instance = AWS::RDS::DBInstance.new(instance_id)
      raise "DB Instance[#{instance_id}] does not exist." unless db_instance.exists?
      db_instance
    end

    def rds
      @rds ||= AWS::RDS.new
      @rds
    end

    def print_snapshots(snapshots)
      tp snapshots,
         {snapshot_id: {display_method: :id}},
         :status,
         {gb: {display_method: :allocated_storage}},
         {type: {display_method: :snapshot_type}},
         {engine: lambda { |i| "#{i.engine} #{i.engine_version}" }},
         {zone: {display_method: :availability_zone_name}},
         :created_at,
         :instance_create_time
      #:master_username,
    end

    def print_instances(instances)
      tp instances,
         {instance_id: {display_method: :id}},
         {name: {display_method: :db_name}},
         :status,
         {gb: {display_method: :allocated_storage}},
         :iops,
         {class: {display_method: :db_instance_class}},
         {engine: lambda { |i| "#{i.engine} #{i.engine_version}" }},
         {zone: {display_method: :availability_zone_name}},
         :multi_az,
         {:endpoint_address => {:width => 120}},
         {port: {display_method: :endpoint_port}},
         #:latest_restorable_time,
         #:auto_minor_version_upgrade,
         #:read_replica_db_instance_identifiers,
         #:read_replica_source_db_instance_identifier,
         #:backup_retention_period,
         #:master_username,
         :created_at
    end
  end


  ###########################################
  #
  #
  #
  desc 'Setup AWS.config and merge/override environments into one resolved configuration'
  task :config do |t, args|

    # set the default environment to be development
    #env = ENV['RAILS_ENV'] || Rails.env || 'development'
    env = ENV['RAILS_ENV'] || 'development'

    # load the configuration from same dir (for standalone CI purposes) or from the rails config dir if within the rails project
    filename = EbConfig.resolve_path('eb.yml')
    unless File.exists? filename
      filename = EbConfig.resolve_path('config/eb.yml')
    end
    EbConfig.load!(env, filename)

    # Let's be explicit regardless of 'production' being the eb's default shall we? Set RACK_ENV and RAILS_ENV based on the given environment
    EbConfig.set_option(:'aws:elasticbeanstalk:application:environment', 'RACK_ENV', "#{EbConfig.environment}")
    EbConfig.set_option(:'aws:elasticbeanstalk:application:environment', 'RAILS_ENV', "#{EbConfig.environment}")

    # resolve the version and set the APP_VERSION environment variable
    resolve_version(args)

    # configure aws credentials.  Depending on the called task, this may not be necessary parent task should call #credentials! for validation.
    AWS.config(credentials) unless credentials.nil?

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
  desc 'Package zip source bundle for Elastic Beanstalk and generate external Rakefile'
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
      Zip::File.open(package_file, Zip::File::CREATE) do |archive|

        puts "\nCreating archive (#{package_file}):" if package_verbose?
        files.each do |f|

          if File.directory?(f)
            puts "\t#{f}" if package_verbose?
            archive.add(f, f)
          else
            puts "\t\t#{f}" if package_verbose?
            archive.add(f, f)
          end
        end
      end


      # write Rakefile for external CI/CD package deployment
      File.open(package_rakefile, "w+") do |f|
        f.write("spec = Gem::Specification.find_by_name('elastic-beanstalk', '>= #{Elastic::Beanstalk::VERSION}')\n")
        f.write("load \"\#{spec.gem_dir}/lib/elastic/beanstalk/tasks/eb.rake\"")
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

    # ensure credentials
    credentials!

    package = resolve_absolute_package_file

    # check package file
    raise "Package file not found #{package} (also checked current dir).  Be sure to run the :package task subsequent to any :deploy attempts." if !File.exists? package

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
        package_bucket: EbConfig.package_bucket,
        keep_latest: EbConfig.keep_latest,
        version_prefix: EbConfig.version_prefix,
        settings: EbConfig.option_settings,
        strategy: EbConfig.strategy.to_sym,
        package: package
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
    file = resolve_absolute_package_file
    if version.nil? && File.exists?(file)
      # otherwise use the MD5 hash of the package file
      version = Digest::MD5.file(file).hexdigest
    end

    # set the var, depending on the sequence of calls, this may be nil
    #   (i.e. :show_config with no :version argument) so omit it until we have something worthwhile.
    EbConfig.set_option(:'aws:elasticbeanstalk:application:environment', 'APP_VERSION', "#{version}") unless version.nil?
  end

  def print_config
    # display helpful for figuring out problems later in the deployment logs.
    puts "\n----------------------------------------------------------------------------------"
    puts 'Elastic Beanstalk configuration:'
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

  # validate file exists
  def credentials!
    raise "\nFailed to load AWS secrets: #{aws_secrets_file}.\nFile contents should look like:\naccess_key_id: XXXX\nsecret_access_key: XXXX\n\n" unless File.exists?(aws_secrets_file)
    credentials

    ['access_key_id', 'secret_access_key'].each do |key|
      value = credentials[key]
      raise "\nThe #{key} must be specified in the #{aws_secrets_file}.\n\n" if value.nil?
    end
  end

  # load from a user directory i.e. ~/.aws/acme.yml
  def credentials
    # load secrets from the user home directory
    @credentials = YAML::load_file(aws_secrets_file) if @credentials.nil?
    @credentials
  end

  def package_verbose?
    EbConfig.package[:verbose] || false
  end

  def resolve_absolute_package_file

    # first see if it is in the current dir, i.e. CI environment where the generated rakefile and pkg is dropped in the same place
    file = EbConfig.resolve_path(package_file_name)
    return file if File.exists? file

    file = EbConfig.resolve_path(package_file)
    return file
  end

  def package_file
    "#{EbConfig.package[:dir]}/#{package_file_name}"
  end

  def package_file_name
    "#{EbConfig.app}.zip"
  end

  def package_rakefile
    "#{EbConfig.package[:dir]}/Rakefile"
  end

  def aws_secrets_file
    File.expand_path("~/.aws/#{EbConfig.app}.yml")
  end
end