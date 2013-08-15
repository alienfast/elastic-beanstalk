# Slightly modified from https://gist.github.com/morhekil/998709

# Symbolizes all of hash's keys and subkeys.
# Also allows for custom pre-processing of keys (e.g. downcasing, etc)
# if the block is given:
#
# somehash.deep_symbolize { |key| key.downcase }
#
# Usage: either include it into global Hash class to make it available to
#        to all hashes, or extend only your own hash objects with this
#        module.
#        E.g.:
#        1) class Hash; include DeepSymbolizable; end
#        2) myhash.extend DeepSymbolizable
module DeepSymbolizable
  def deep_symbolize(invert = false, &block)
    method = self.class.to_s.downcase.to_sym
    symbolizers = DeepSymbolizable::Symbolizers
    symbolizers.respond_to?(method) ? symbolizers.send(method, self, invert, &block) : self
  end

  module Symbolizers
    extend self

    # the primary method - symbolizes keys of the given hash,
    # preprocessing them with a block if one was given, and recursively
    # going into all nested enumerables
    def hash(hash, invert, &block)
      hash.inject({}) do |result, (key, value)|
        # Recursively deep-symbolize subhashes
        value = _recurse_(value, invert, &block)

        # Pre-process the key with a block if it was given
        key = yield key if block_given?

        if invert
          # UN-Symbolize the key
          s_key = key.to_s rescue key

          # write it back into the result and return the updated hash
          result[s_key] = value

        else
          # Symbolize the key string if it responds to to_sym
          sym_key = key.to_sym rescue key

          # write it back into the result and return the updated hash
          result[sym_key] = value
        end
        result
      end
    end

    # walking over arrays and symbolizing all nested elements
    def array(ary, invert, &block)
      ary.map { |v| _recurse_(v, invert, &block) }
    end

    # handling recursion - any Enumerable elements (except String)
    # is being extended with the module, and then symbolized
    def _recurse_(value, invert, &block)
      if value.is_a?(Enumerable) && !value.is_a?(String)
        # support for a use case without extended core Hash
        value.extend DeepSymbolizable unless value.class.include?(DeepSymbolizable)
        value = value.deep_symbolize(invert, &block)
      end
      value
    end
  end

end

# include in all Hash objects
class Hash; include DeepSymbolizable; end