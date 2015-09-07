require 'singleton'
require 'dry/config'

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
    class Config < Dry::Config::Base

      include Singleton
      # it's a singleton, thus implemented as a self-extended module
      # extend self

      def initialize(options = {})
        super({interpolation: false}.merge options)
      end

      def seed_default_configuration
        # seed the sensible defaults here
        @configuration = {
            environment: nil,
            secrets_dir: '~/.aws',
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

      def load!(environment = nil, filename = resolve_path('config/eb.yml'))
        super(environment, filename)
      end


      def resolve_path(relative_path)
        if defined?(Rails)
          Rails.root.join(relative_path)
        elsif defined?(Rake.original_dir)
          File.expand_path(relative_path, Rake.original_dir)
        else
          File.expand_path(relative_path, Dir.pwd)
        end
      end

      # def options
      #   @configuration[:options] = {} if @configuration[:options].nil?
      #   @configuration[:options]
      # end

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
            :'namespace' => "#{namespace}",
            :'option_name' => "#{option_name}",
            :'value' => "#{value}"
        }
      end
    end
  end
end