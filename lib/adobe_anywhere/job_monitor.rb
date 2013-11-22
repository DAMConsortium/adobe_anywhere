require 'mongo'
require 'pp'

require 'adobe_anywhere/api/utilities'
require 'adobe_anywhere/database/helpers/jobs'
require 'adobe_anywhere/job_processor'
require 'adobe_anywhere/poller'
module AdobeAnywhere

  class JobMonitor

    def self.run(*args); new(*args).run end # self.run
    def self.poll(params = { }); Poller.poll(params.merge( :worker => new(params) )) end # self.poll
    def self.start(params = { }); Poller.start(params.merge( :worker => new(params) )) end # self.start

    attr_accessor :logger

    attr_accessor :db

    attr_accessor :aa

    #attr_accessor :send_job_to_processor_on_state_change
    attr_accessor :job_processor

    attr_accessor :send_job_to_processor_on_state_change

    class Jobs < AdobeAnywhere::Database::Helpers::Jobs; end

    def initialize(args = {})

      initialize_logger(args)
      initialize_adobe_anywhere(args)
      initialize_db(args)
      initialize_job_processor(args)

      @send_job_to_processor_on_state_change = args.fetch(:send_job_to_processor_on_state_change, true)
    end # initialize

    def initialize_logger(args = {})
      @logger = args[:logger] || Logger.new(args[:log_to] || STDOUT)
      logger.level = args[:log_level] if args[:log_level]
      args[:logger] ||= logger
      logger
    end # initialize_logger

    def initialize_adobe_anywhere(args = { })
      @aa = args[:adobe_anywhere] || begin
        _aa = AdobeAnywhere::API::Utilities.new(args)
        _aa.http.log_request_body = true
        _aa.http.log_response_body = true
        _aa.http.log_pretty_print_body = true

        _aa.login

        _aa
      end
    end # initialize_adobe_anywhere

    def initialize_db(args = {})
      @db = AdobeAnywhere::Database.new(args)
      Jobs.db = db
    end # initialize_db

    def initialize_job_processor(args = { })
      @job_processor = AdobeAnywhere::JobProcessor.new(args)
      job_processor.aa = aa
      job_processor.db = db
    end # initialize_job_processor

    def run
      process_jobs
    end # run

    # @param [Hash] job_details The output of a JobDetails call for a job
    # @return [False|String] The URI to the job details
    def get_self_link_href_from_job_details(job_details, options = { })
      raise_exceptions = options.fetch(:raise_exceptions, true)
      unless job_details.is_a?(Hash)
        return false unless raise_exceptions
        raise ArgumentError, "job_details argument is required to be a hash. job_details class name: #{job_details.class.name}. job_details: #{job_details}"
      end

      links = job_details['links']
      unless links.is_a?(Array)
        return false unless raise_exceptions
        raise Argument, "job_details['links'] must be an array. job_details = #{job_details}"
      end

      self_link_index = links.index { |link| link['rel'].downcase == 'self' }
      unless self_link_index
        return false unless raise_exceptions
        raise Argument, "job_details['links']['self'] not found. job_details = #{job_details}"
      end

      self_link = links[self_link_index]
      unless self_link.is_a?(Hash)
        return false unless raise_exceptions
        raise Argument, "job_details['links']['self']['href'] not found. job_details = #{job_details}"
      end

      self_link['href']
    end # get_self_link_href_from_job_details

    # @return [Hash]
    def get_latest_job_details_from_database(job)
      job_id = job['jcr:name']
      job_record = Jobs.find_by_id(job_id)
    end

    # @param [Hash] job
    def get_latest_job_details_from_anywhere(job)
      self_link_href = case job
                         when Hash; job.include?('links') ? get_self_link_href_from_job_details(job) : false
                         when String; job.include?('/') ? job : false
                       end
      return false unless self_link_href
      aa.http_get(self_link_href)
      aa.success? ? aa.parsed_response : false
    end

    # @return [Hash] { details: [Hash], difference: [Hash] }
    def get_latest_job_details(job, options = { })
      update_database = options[:update_database]
      job_details = get_latest_job_details_from_anywhere(job)
      if job_details
        _response = update_database ?
            update_job_status(job_details) :
            { :details => job_details, :difference => { } }
      else
        job_details = get_latest_job_details_from_database(job)
        _response = { :details => job_details, :difference => { } }
      end
      _response
    end # get_latest_job_details

    # @return [Hash] { details: [Hash], difference: [Hash] }
    def update_job_status(job_detail)
      response = Jobs.save_changes(job_detail, :return_diff => true)
      response[:details] = job_detail
      response
    end
    alias :save_job_status :update_job_status

    def process_job(job)
      job_details = get_latest_job_details_from_anywhere(job)
      job_update = update_job_status(job_details)
      job_diff = job_update[:difference]
      if job_diff['ea:jobState'] and send_job_to_processor_on_state_change
        logger.debug { "Job State Has Changed. #{job_diff}" }
        job_processor.process_job(job)
      end

      #aa.production_get(href_info['production_id'])
      job_diff
    end

    def process_jobs(jobs = nil)
      jobs ||= get_jobs
      jobs.each { |job| process_job(job) }
    end

    def get_job(params = {})
      job_url = params[:job_url]
      aa.http_get(job_url)
      #puts aa.parsed_response
      aa.parsed_response
    end # get_job

    def get_jobs
      aa.job_list

      jobs = aa.parsed_response['jobs']
      stats = aa.parsed_response['stats']

      if stats['totalResults'] > stats['count']
        loop do
          links          = aa.parsed_response['links']
          next_page_link = false
          links.each { |link| next_page_link = link and break if link['title'] == 'Next Page' }
          break unless next_page_link
          aa.http_get(next_page_link['href'])
          jobs += aa.parsed_response['jobs']
        end
      end
      jobs
    end # get_jobs

  end # JobMonitor

end # AdobeAnywhere
