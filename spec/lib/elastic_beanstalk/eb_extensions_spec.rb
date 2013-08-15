require 'spec_helper'

describe EbExtensions do

  before do
    EbConfig.clear
    EbConfig.load!(:development, Rails.root.join('spec/lib/eb_spec.yml'))
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
end