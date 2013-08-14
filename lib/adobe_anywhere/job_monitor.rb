require 'mongo'
require 'pp'

require 'adobe_anywhere/api/utilities'
require 'adobe_anywhere/job_database'
module AdobeAnywhere

  class JobMonitor

    attr_accessor :logger

    attr_accessor :db

    attr_accessor :aa

    def initialize(params = {})
      @logger = params[:logger] ||= Logger.new(params[:log_to] || STDOUT)
      log_level = params[:log_level]
      logger.level = log_level if log_level

      database_params = params

      @db = AdobeAnywhere::JobDatabase.new(database_params)

      @aa = AdobeAnywhere::API::Utilities.new(params)
      aa.http.log_request_body = true
      aa.http.log_response_body = true
      aa.http.log_pretty_print_body = true

      aa.login
    end # initialize

    def get_job(params = {})
      job_url = params[:job_url]
      aa.http_get(job_url)
      puts aa.parsed_response
    end # get_job


    def get_jobs
      aa.job_list

      jobs = aa.parsed_response['jobs']
      stats = aa.parsed_response['stats']

      loop do
        links = aa.parsed_response['links']
        next_page_link = false
        links.each { |link| next_page_link = link and break if link['title'] == 'Next Page' }
        break unless next_page_link
        aa.http_get(next_page_link['href'])
        jobs += aa.parsed_response['jobs']
      end if stats['totalResults'] > stats['count']

      jobs.each do |job|
        links = job['links']
        self_link_index = links.index { |link| link['rel'].downcase == 'self' }
        self_link = links[self_link_index]
        self_link_href = self_link['href']

        href_info = aa.production_job_href_parse(self_link_href)

        aa.http_get(self_link_href)
        job_detail = aa.parsed_response
        db.job_save_changes(job_detail)

        aa.production_get(href_info['production_id'])

      end

    end # get_jobs

  end # JobMonitor

end # AdobeAnywhere

options = { }

options[:host_address] = '10.42.1.109'

jm = AdobeAnywhere::JobMonitor.new(options)
jm.get_jobs
