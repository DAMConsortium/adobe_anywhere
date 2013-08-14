module Mongoize
  # A utility module to process hash keys so that unsafe characters and symbols
  # will be changed to a parseable value that can be restored once retrieved from mongo
  #
  #
  # i = Mongoize::Collection.to_mongo({ "A/B\\C.D\"E*F<G>H.I:J|K?L " => { "A/B\\C.D\"E*F<G>H.I:J|K?L " => { "A/B\\C.D\"E*F<G>H.I:J|K?L " => "A/B\\C.D\"E*F<G>H.I:J|K?L " } } })
  # # => => {"A!47!B!92!C!46!D!34!E!42!F!60!G!62!H!46!I!58!J!124!K!63!L!32!"=>{"A!47!B!92!C!46!D!34!E!42!F!60!G!62!H!46!I!58!J!124!K!63!L!32!"=>{"A!47!B!92!C!46!D!34!E!42!F!60!G!62!H!46!I!58!J!124!K!63!L!32!"=>"A/B\\C.D\"E*F<G>H.I:J|K?L "}}}
  # o = Mongoize.from_mongo(i)
  # # => {"A/B\\C.D\"E*F<G>H.I:J|K?"=>{"A/B\\C.D\"E*F<G>H.I:J|K?"=>{"A/B\\C.D\"E*F<G>H.I:J|K?"=>"A/B\\C.D\"E*F<G>H.I:J|K?"}}}
  #
  #
  # i = Mongoize.to_mongo({ "A/B\\C.D\"E*F<G>H.I:J|K?" => 'value' })
  # # => {"A!47!B!92!C!46!D!34!E!42!F!60!G!62!H!46!I!58!J!124!K!63!"=>"value"}
  # o = Mongoize.from_mongo(i)
  # # => {"A/B\\C.D\"E*F<G>H.I:J|K?"=>"value"}
  #
  # i = Mongoize::Document.to_mongo({ "A.B$" => 'value' })
  #
  # Database Name Pattern: /^\$|[\/\\\.\"\*\<\>\:\|\?|]/
  # Collection Name Pattern: /^\$|\./
  # Field Name Pattern: /^\$|\./
  #
  class Common

    def self.default_params
      @default_params ||= {
          invalid_chr_pattern: /^\$|\./ , # First character is a $ or any periods or spaces
          recursive: true,
          prefix: '!',
          suffix: '!',
          symbol_indicator: 'sym',
      }
    end # default_params

    def self.default_params=(value)
      @default_params = value
    end # default_params=

    def self.filter_hash(search_for = @default_params, search_in)
      hash_out = { }
      search_for.each { |parameter, default_value|
        case parameter
          when Symbol, String, Integer
            hash_out[parameter] = search_in.fetch(parameter, default_value) if search_in.has_key? parameter or !default_value.nil?
          when Hash, Array
            name, default_value = parameter.dup.shift
            hash_out[name] = search_in.fetch(name, default_value)
        end
      }
      hash_out
    end # filter_hash

    def self.to_mongo(value_in, params = { })
      case value_in
        when Array
          return value_in.dup.map { |v| to_mongo(v, params) }
        when Hash
          params = filter_hash(default_params, params)
          v = process_value_to_mongo(value_in, params[:invalid_chr_pattern], params[:prefix], params[:suffix], params[:symbol_indicator], params[:recursive])
          #puts ":to_mongo #{hash_in} -> #{v}"
          return v
        else
          return value_in
      end
    end # to_mongo

    def self.from_mongo(value_in, params = { })
      case value_in
        when Array
          return value_in.dup.map { |v| from_mongo(v, params) }
        when Hash
          params = filter_hash(default_params, params)
          # puts "######### PARAMS #{params}"
          v = process_value_from_mongo(value_in, params[:prefix], params[:suffix], params[:symbol_indicator], params[:recursive])
          # puts "## V #{v}"
          #puts ":from_mongo #{hash_in} -> #{v}"
          return v
        else
          return value_in
      end
    end # from_mongo

    def self.process_hash_to_mongo(hash_in, sub_pattern, prefix, suffix, symbol_indicator, recursive)
      _symbol_indicator =  "#{prefix}#{symbol_indicator}#{suffix}"
      hash_out = { }
      hash_in.each { |key, value|
        key = "#{_symbol_indicator}#{key.to_s}" if key.is_a? Symbol
        #if key.is_a?(Hash)
        #  key = process_hash_to_mongo(key, sub_pattern, prefix, suffix, symbol_indicator, recursive) if recursive
        #else
        key = key.gsub(sub_pattern) { |s| "#{prefix}#{s.ord.to_s}#{suffix}" }
        #end
        value = process_hash_to_mongo(value, sub_pattern, prefix, suffix, symbol_indicator, recursive) if recursive and value.is_a? Hash
        hash_out[key] = value
      }
      hash_out
    end # process_hash_to_mongo

    def self.process_hash_from_mongo(hash_in, prefix, suffix, symbol_indicator, recursive)
      _symbol_indicator =  "#{prefix}#{symbol_indicator}#{suffix}"
      symbol_indicator_len = _symbol_indicator.length
      sub_pattern = /#{prefix}([0-2]*[0-9]{1,2})#{suffix}/

      hash_out = { }
      hash_in.each { |key, value|
        #if key.is_a?(Hash)
        #  key = process_hash_from_mongo(key, prefix, suffix, symbol_indicator, recursive) if recursive
        #else
        key = key.gsub(sub_pattern) { |s| $1.to_i.chr }
        key = key[(symbol_indicator_len)..-1].to_sym if key.start_with? "#{_symbol_indicator}"
        #end
        value = process_hash_from_mongo(value, prefix, suffix, symbol_indicator, recursive) if recursive and value.is_a? Hash
        hash_out[key] = value
      }
      hash_out
    end # process_hash_from_mongo

    def self.process_value_to_mongo(value_in, sub_pattern, prefix, suffix, symbol_indicator, recursive)
      case value_in
        when Array
          return value_in.dup.map { |value| process_value_to_mongo(value, sub_pattern, prefix, suffix, symbol_indicator, recursive) } if recursive
          return value_in
        when Hash
          _symbol_indicator =  "#{prefix}#{symbol_indicator}#{suffix}"
          value_out = { }
          value_in.each { |key, value|
            key = "#{_symbol_indicator}#{key.to_s}" if key.is_a? Symbol
            # Ran into an issue where key was nil so we do a is_a?(String) check
            key = key.gsub(sub_pattern) { |s| "#{prefix}#{s.ord.to_s}#{suffix}" } if key.is_a?(String)
            value = process_value_to_mongo(value, sub_pattern, prefix, suffix, symbol_indicator, recursive) if recursive and (value.is_a?(Hash) or value.is_a?(Array))
            value_out[key] = value
          }
          return value_out
        else
          return value_in
      end
    end # process_hash_to_mongo

    def self.process_value_from_mongo(value_in, prefix, suffix, symbol_indicator, recursive)
      case value_in
        when Array
          return value_in.dup.map { |value| process_value_from_mongo(value, prefix, suffix, symbol_indicator, recursive) } if recursive
          return value_in
        when Hash
          _symbol_indicator =  "#{prefix}#{symbol_indicator}#{suffix}"
          symbol_indicator_len = _symbol_indicator.length
          sub_pattern = /#{prefix}([0-2]*[0-9]{1,2})#{suffix}/
          value_out = { }
          value_in.each { |key, value|
            key = key.gsub(sub_pattern) { |s| $1.to_i.chr }
            key = key[(symbol_indicator_len)..-1].to_sym if key.start_with? "#{_symbol_indicator}"
            value = process_value_from_mongo(value, prefix, suffix, symbol_indicator, recursive) if recursive and (value.is_a?(Hash) or value.is_a?(Array))
            value_out[key] = value
          }
          return value_out
        else
          return value_in
      end
    end # process_hash_from_mongo

    def self.name_to_mongo(value, params = { })
      params = filter_hash(default_params, params)
      process_name_to_mongo(value, params[:invalid_chr_pattern], params[:prefix], params[:suffix], params[:symbol_indicator], params[:recursive])
    end # name_to_hash

    def self.process_name_to_mongo(value, sub_pattern, prefix, suffix, symbol_indicator, recursive)
      symbol_indicator =  "#{prefix}#{symbol_indicator}#{suffix}"
      value = value
      value = "#{symbol_indicator}#{value.to_s}" if value.is_a? Symbol
      value = value.gsub(sub_pattern) { |s| "#{prefix}#{s.ord.to_s}#{suffix}" }
      value
    end # process_name_to_mongo

    def self.name_from_mongo(value, params = { })
      params = filter_hash(default_params, params)
      process_name_from_mongo(value, params[:prefix], params[:suffix], params[:symbol_indicator], params[:recursive])
    end # name_from_mongo

    def self.process_name_from_mongo(value, prefix, suffix, symbol_indicator, recursive)
      symbol_indicator =  "#{prefix}#{symbol_indicator}#{suffix}"
      symbol_indicator_len = symbol_indicator.length
      sub_pattern = /#{prefix}([0-2]*[0-9]{1,2})#{suffix}/

      value = value.gsub(sub_pattern) { |s| $1.to_i.chr }
      value = value[(symbol_indicator_len)..-1].to_sym if key.start_with? "#{symbol_indicator}"
      value
    end # process_name_from_mongo

  end # Common

  class Database < Common
    self.default_params = self.default_params.merge!({ invalid_chr_pattern: /^\$|[\/\\\.\"\*\<\>\:\|\?|]/ })
    class << self
      alias :to_mongo :name_to_mongo
      alias :from_mongo :name_from_mongo
    end
  end # Database

  class Collection < Common
    class << self
      alias :to_mongo :name_to_mongo
      alias :from_mongo :name_from_mongo
    end
  end # Collection

  class Document < Common; end # Document

  def self.to_mongo(*args); Common.to_mongo(*args) end
  def self.from_mongo(*args); Common.from_mongo(*args) end

end # Mongoize