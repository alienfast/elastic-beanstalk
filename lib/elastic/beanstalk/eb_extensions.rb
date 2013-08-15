module Elastic
  module Beanstalk

    module EbExtensions
      # it's a singleton, thus implemented as a self-extended module
      extend self

      def write_extensions

        ebextensions = EbConfig.ebextensions
        return if ebextensions.nil?

        Dir.mkdir absolute_file_name(nil) rescue nil

        ebextensions.each_key do |filename|
          contents = EbConfig.ebextensions[filename]

          filename = absolute_file_name(filename)

          # when converting to_yaml, kill the symbols as EB doesn't like it.
          contents = contents.deep_symbolize(true).to_yaml.gsub(/---\n/, "")
          #puts "\n#{filename}:\n----------------------------------------------------\n#{contents}----------------------------------------------------\n"
          File.write(filename, contents)
        end
      end

      def delete_extensions
        ebextensions = EbConfig.ebextensions
        return if ebextensions.nil?

        ebextensions.each_key do |filename|
          File.delete(absolute_file_name filename)
        end
      end

      def absolute_file_name(filename)
        EbConfig.resolve_path(".ebextensions/#{filename}")
      end

      def ebextensions_dir(filename)
        EbConfig.resolve_path(".ebextensions/#{filename}")
      end
    end
  end
end