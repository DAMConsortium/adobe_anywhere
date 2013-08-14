require 'mongo'
require 'mongoize'

module AdobeAnywhere

  class JobDatabase

    DEFAULT_DATABASE_NAME = 'AdobeAnywhere'
    DEFAULT_COLLECTION_NAME = 'jobs'

    class Mongo

      attr_accessor :client, :db, :col

      # @param [String] :database_name
      # @param [String] :collection_name
      def initialize(params = { })
        @client = ::Mongo::MongoClient.new(params[:database_host_name], params[:database_port])

        @db = client.db(params[:database_name] || DEFAULT_DATABASE_NAME)
        db.authenticate(params[:database_user_name, params[:database_password]]) if params[:database_user_name]

        @col = @db.collection(params[:collection_name] || DEFAULT_COLLECTION_NAME)
      end

      def find(*args); Mongoize.from_mongo(col.find(Mongoize.to_mongo(*args)).to_a) end # find

      def find_one(*args); Mongoize.from_mongo(col.find_one(Mongoize.to_mongo(*args))) end # find_one

      def insert(*args); col.insert(Mongoize.to_mongo(*args)) end # insert

      def remove(*args); col.remove(Mongoize.to_mongo(*args)) end # remove

      def update(*args); col.update(Mongoize.to_mongo(*args)) end # update

      def save(*args); col.save(Mongoize.to_mongo(*args)) end # save

    end # Mongo

    attr_accessor :db

    def initialize(*args)
      @db = Mongo.new(*args)
    end # initialize

    def delete(*args); db.remove(*args) end # delete
    alias :remove :delete

    def find(*args); db.find(*args) end # find_all
    alias :find_all :find

    def find_one(*args) db.find_one(*args) end # find_by_id
    alias :get :find_one

    def insert(*args); db.insert(*args) end # insert
    alias :add :insert

    def update(*args); db.update(*args) end # update

    def save(*args); db.save(*args) end # save

    def job_save_changes(job)
      job_id = job['jcr:name']
      job_etag = job['jcr:etag']
      job_state = job['ea:jobState']
      job_last_modified = job['jcr:lastModified']
      job_record = @db.find_one('_id' => job_id)
      unless job_record
        job_type = job['ea:jobType']
        job_record = {
            '_id' => job_id,
            'type' => job_type,
            'detail' => { job_etag => job },
            'most_recent_etag' => job_etag,
            'most_recent_state' => job_state,
            'most_recent_lastModified' => job_last_modified,
            'created_at' => Time.now.to_i,
            'modified_at' => Time.now.to_i
        }
        db.insert(job_record)
        job_diff = job
      else
        most_recent_etag = job_record['most_recent_etag']
        if job_etag != most_recent_etag
          job_record['detail'][job_etag] = job
          job_record['most_recent_etag'] = job_etag
          job_record['most_recent_state'] = job_state
          job_record['most_recent_lastModified'] = job_last_modified
          job_record['modified_at'] = Time.now.to_i
          db.save(job_record)

          # Diff job and job_

        else
          job_diff = { }
        end

        #existing_job_detail = job_record['detail']
        #detail_match = (job_detail == existing_job_detail)
        #logger.debug { "Detail Match: #{detail_match}"}
        #unless detail_match
        #  logger.debug { 'Record has changed.' }
        #end
      end
      job_record
    end # save_if_newer

    def job_add_callback_event(job, event_details)
      job_record ||= job_save_changes(job)
      return unless job_record

      events = job_record['events'] ||= { }
      callbacks = events['callbacks'] ||= [ ]
      callbacks << event_details
      job_record['events']['callbacks'] = callbacks
      job_record['modified_at'] = Time.now.to_i
      db.save(job_record)
    end # job_add_callback_event


  end # JobDatabase

end # AdobeAnywhere