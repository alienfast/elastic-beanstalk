require 'spec_helper'

describe EbExtensions do

  before do
    EbConfig.clear
    EbConfig.load!(:development, config_file_path)
  end

  it "#write_extensions and #delete_extensions" do
    EbExtensions.write_extensions

    EbConfig.ebextensions.each_key do |filename|
      filename = EbExtensions.absolute_file_name(filename)
      expect(File.exists? filename).to be_true
    end

    EbExtensions.delete_extensions
    EbConfig.ebextensions.each_key do |filename|
      filename = EbExtensions.absolute_file_name(filename)
      expect(File.exists? filename).to be_false
    end
  end

  def config_file_path
    File.expand_path('../eb_spec.yml', __FILE__)
  end
end