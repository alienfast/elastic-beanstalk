require 'deep_symbolize'
require 'yaml'

module Elastic
  module Beanstalk
#
# EbConfig allows for default settings and mounting a specific environment with overriding
#   hash values and merging of array values.
#
#   NOTE: Anything can be overridden and merged into top-level settings (hashes) including
#   anything that is an array value.  Array values are merged *not* replaced.  If you think
#   something is screwy, see the defaults in the #init as those add some default array values.
#   If this behavior of merging arrays or the defaults are somehow un-sensible, file an issue and we'll revisit it.
#
    module Config
      # it's a singleton, thus implemented as a self-extended module
      extend self

      def init

        # seed the sensible defaults here
        @configuration = {
            environment: nil,
            disallow_environments: %w(cucumber test),
            strategy: :blue_green,
            package: {
                dir: 'pkg',
                verbose: false,
                includes: %w(**/* .ebextensions/**/*),
                exclude_files: [],
                exclude_dirs: %w(pkg tmp log test-reports)
            },
            options: {}
        }
      end

      init()
      attr_reader :configuration

      # This is the main point of entry - we call Settings.load! and provide
      # a name of the file to read as it's argument. We can also pass in some
      # options, but at the moment it's being used to allow per-environment
      # overrides in Rails
      def load!(environment = nil, filename = resolve_path('config/eb.yml'))

        # merge all top level settings with the defaults set in the #init
        #@configuration.deep_merge!( YAML::load_file(filename).deep_symbolize )
        deep_merge!(@configuration, YAML::load_file(filename).deep_symbolize)

        # add the environment to the top level settings
        @configuration[:environment] = (environment.nil? ? nil : environment.to_s)

        # overlay the specific environment if provided
        if environment && @configuration[environment.to_sym]

          # this is environment specific, so prune any environment
          # based settings from the initial set so that they can be overlaid.
          [:development, :test, :staging, :production].each do |env|
            @configuration.delete(env)
          end

          # re-read the file
          environment_settings = YAML::load_file(filename).deep_symbolize

          # snag the requested environment
          environment_settings = environment_settings[environment.to_sym]

          # finally overlay what was provided
          #@configuration.deep_merge!(environment_settings)
          deep_merge!(@configuration, environment_settings)
        end


        #ap @configuration
        #generate_accessors
      end

      def deep_merge!(target, data)
        merger = proc { |key, v1, v2|
          if (Hash === v1 && Hash === v2)
            v1.merge(v2, &merger)
          elsif (Array === v1 && Array === v2)
            v1.concat(v2)
          else
            v2
          end
        }
        target.merge! data, &merger
      end

      def reload!(options = {}, filename)
        clear
        #filename.nil? ?
        load!(options) # : load!(options, filename)
      end

      def to_yaml

      end

      def method_missing(name, *args, &block)
        @configuration[name.to_sym] ||
            #fail(NoMethodError, "Unknown settings root \'#{name}\'", caller)
            nil
      end

      def clear
        init
      end

      def options
        @configuration[:options] = {} if @configuration[:options].nil?
        @configuration[:options]
      end

      # custom methods for the specifics of eb.yml settings
      def option_settings
        result = []
        options.each_key do |namespace|
          options[namespace].each do |option_name, value|
            result << to_option_setting(namespace, option_name, value)
          end
        end

        #{"option_settings" => result}
        result
      end

      def set_option(namespace, option_name, value)
        namespace = namespace.to_sym

        if options[namespace].nil?
          options[namespace] = {option_name.to_sym => value}
        else
          options[namespace][option_name.to_sym] = value
        end

        #puts '888888hello'
      end

      def find_option_setting(name)
        name = name.to_sym
        options.each_key do |namespace|
          options[namespace].each do |option_name, value|
            if option_name.eql? name
              return to_option_setting(namespace, option_name, value)
            end
          end
        end
        return nil
      end

      def find_option_setting_value(name)
        o = find_option_setting(name)
        o[:value] unless o.nil?
      end

      def to_option_setting(namespace, option_name, value)
        {
            :"namespace" => "#{namespace}",
            :"option_name" => "#{option_name}",
            :"value" => "#{value}"
        }
      end

      def resolve_path(relative_path)

        if defined?(Rails)
          Rails.root.join(relative_path)
        elsif defined?(Rake.original_dir)
          Rake.original_dir.join(relative_path)
        else
          File.expand_path(relative_path, Dir.pwd)
        end
      end


      #def environment
      #  @configuration[:environment]
      #end
      #
      #def options
      #  @configuration[:options]
      #end

      private

      #def generate_accessors
      #  # generate a method for accessors
      #  @configuration.each do |key, value|
      #    define_method(key) do
      #      value
      #    end unless ['options', 'environment'].include? key
      #  end
      #end
    end

  end
end