require 'mongo'
class Database

  DEFAULT_DATABASE_NAME = 'general'

  class Mongo

    attr_accessor :client, :db, :col

    # @param [Hash] args
    # @option args [String] :database_host_address
    # @option args [String] :database_port
    # @option args [String] :database_name
    # @option args [String] :collection_name
    # @option args [String] :database_username
    # @option args [String] :database_password
    def initialize(args = { })
      @client = ::Mongo::MongoClient.new(args[:database_host_address], args[:database_port])

      @db = client.db(args[:database_name] || DEFAULT_DATABASE_NAME)
      db.authenticate(args[:database_username, args[:database_password]]) if args[:database_username]

      @col = db.collection(args[:collection_name]) if args[:collection_name]
    end

    def collection=(collection_name)
      @col = db.collection(collection_name)
    end # collection

    def find_all
      find({ })
    end # find_all

    def find(selector, options = { });
    #puts "DATABASE: #{@db.name}\nCOLLECTION: #{@col.name}\nSELECTOR: #{selector}\nOPTIONS: #{options}"
    result = col.find(selector, options).to_a
    #puts "RESULT: (#{result.count}) #{result}"
    result
    end # find

    def find_one(*args); col.find_one(*args) end # find_one

    def insert(*args); col.insert(*args) end # insert

    def remove(*args); col.remove(*args) end # remove

    def update(id, document, opts = { })
      puts "#{self.class.name}.#{__method__}(#{id} #{document} #{opts}) DATABASE NAME: #{db.name} COLLECTION NAME: #{col.name}"
      col.update(id, document, opts)
    end # update

    def save(*args); col.save(*args) end # save

  end # Mongo

  def self.new(args = { })
    args[:database_name] ||= self.const_get(:DEFAULT_DATABASE_NAME)
    #puts "DATABASE NAME: #{args[:database_name]}"
    args[:collection_name] ||= self.const_get(:DEFAULT_COLLECTION_NAME) if self.const_defined?(:DEFAULT_COLLECTION_NAME)
    Mongo.new(args)
  end

end # Database
