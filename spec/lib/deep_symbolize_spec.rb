# https://gist.github.com/morhekil/998709

require 'rspec'
require 'deep_symbolize'

describe 'Hash#deep_symbolize' do
  let(:hash) {{}}
  subject do
    #hash.extend DeepSymbolizable
    hash.deep_symbolize
  end

  context 'on simple hash when inverting' do
    let(:hash) {{ 'key1' => 'val1', 'key2' => 'val2' }}
    it {
      h2 = hash.deep_symbolize
      h2.should == { :key1 => 'val1', :key2 => 'val2' }
      h3 = h2.deep_symbolize(true)
      h3.should == { 'key1' => 'val1', 'key2' => 'val2' }
    }
  end


  context 'on simple hash' do
    let(:hash) {{ :key1 => 'val1', 'key2' => 'val2' }}
    it { should == { :key1 => 'val1', :key2 => 'val2' } }
  end

  context 'on nested hash' do
    let(:hash) {{ 'key1' => 'val1', 'subkey' => { 'key2' => 'val2' } }}
    it { should == { :key1 => 'val1', :subkey => { :key2 => 'val2' } } }
  end

  context 'on a hash with nested array' do
    let(:hash) {{ 'key1' => 'val1', 'subkey' => [{ 'key2' => 'val2' }] }}
    it { should == { :key1 => 'val1', :subkey => [{ :key2 => 'val2' }] } }
  end

  describe 'preprocessing keys' do
    subject do
      #hash.extend DeepSymbolizable
      hash.deep_symbolize { |k| k.upcase }
    end
    let(:hash) {{ 'key1' => 'val1', 'subkey' => [{ 'key2' => 'val2' }] }}
    it { should == { :KEY1 => 'val1', :SUBKEY => [{ :KEY2 => 'val2' }] } }
  end
end