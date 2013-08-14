module AdobeAnywhere

  module Utilities

    # Searches a hash for each key as both a string and a symbol, it will return the first match.
    # If a key is found then the key/value pair will be deleted from the params to aid in making subsequent searches
    # faster and to keep unwanted parameters from being passed to subsequent method calls.
    #
    # @param [Hash] hash
    # @param [Symbol|Array<Symbol>] keys
    # @return [Any] (nil) The value associated with the key
    def search_hash!(hash, *keys)
      params = (keys.is_a?(Array) and keys.last.is_a?(Hash)) ? keys.pop : { }
      search_keys_as_symbols = params.fetch(:search_keys_as_symbols, true)
      search_keys_as_strings = params.fetch(:search_keys_as_string, true)

      ignored_strings = params.fetch(:ignored_strings, false)
      case_sensitive = params.fetch(:case_sensitive, true)

      if ignored_strings || case_sensitive
        search_processed_hash_keys = true
        exact_match_first = params.fetch(:exact_match_first, true)

        processed_hash_keys = hash.keys.map do |key|
          key.downcase rescue key if case_sensitive
          if ignored_strings
            ignored_strings = [*ignored_strings]
            ignored_strings.each { |ignored_string| key.gsub(ignored_string, '') }
          end
        end
      end

      [*keys].each do |key|
        key = key.downcase rescue key unless case_sensitive
        ignored_strings.each { |ignored_string| key.gsub(ignored_string, '') } if ignored_strings

        if search_keys_as_symbols
          _key = key.to_sym rescue key
          unless search_processed_hash_keys
            return hash.delete(_key) if exact_match_first && hash.has_key?(_key)
            key_index = processed_hash_keys(_key)
            return hash.delete(hash.keys[key_index]) if key_index
          else
            return hash.delete(_key) if hash.has_key?(_key)
          end
        end

        if search_keys_as_strings
          _key = key.to_s rescue key
          unless search_processed_hash_keys
            return hash.delete(_key) if exact_match_first && hash.has_key?(_key)
            key_index = processed_hash_keys(_key)
            return hash.delete(hash.keys[key_index]) if key_index
          else
            return hash.delete(_key) if hash.has_key?(_key)
          end
        end
      end
      nil
    end # search_hash!

    # The non-destructive version of {#search_hash!}
    #
    # @param [Hash] hash
    # @param [Symbol|Array<Symbol>] keys
    # @return The value associated with the key
    def search_hash(hash, *keys)
      search_hash!(hash.dup, *keys)
    end # search_hash

  end # Utilities

end # AdobeAnywhere

include AdobeAnywhere::Utilities