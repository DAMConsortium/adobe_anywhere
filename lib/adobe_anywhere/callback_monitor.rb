require 'logger'
require 'json'
require 'mongo'
require 'open3'
require 'pp'
require 'shellwords'
require 'sinatra/base'

require 'adobe_anywhere/job_database'
require 'adobe_anywhere/api/utilities'
Sinatra::Request
module AdobeAnywhere

  class CallbackMonitor < Sinatra::Base

    ### ROUTES START
    get /.*/ do
      log_request('GET /')
    end

    post /.*/ do
      log_request('POST /')
      process_request
    end
    ### ROUTES END

    attr_accessor :logger

    attr_accessor :tasks

    attr_accessor :aa

    attr_accessor :db

    attr_accessor :path_substitutions

    attr_accessor :mig_executable_path

    attr_accessor :job

    attr_accessor :production

    attr_accessor :assets

    attr_accessor :asset_media_information

    # @param [Hash] params
    # @option params [Logger] :logger
    # @option params [String] :log_to
    # @option params [Integer] :log_level
    def initialize(params = {})
      @logger ||= params[:logger] || Logger.new(params[:log_to] || STDOUT)
      logger.level = params[:log_level] if params[:log_level]

      logger.debug { 'Initializing Callback Monitor.' }
      database_params = params || { }

      initialize_database(database_params)

      @tasks = self.class.tasks
      @path_substitutions = self.class.path_substitutions || { }
      @mig_executable_path = self.class.mig_executable_path
      @aa = self.class.aa
      super
    end # initialize

    def initialize_database(params = { })
      @db = JobDatabase.new(params.dup)
    end # initialize_database

    # @param [Hash] params
    # @option params []
    def request_to_s(params = { })
      _request = params[:request] || request
      output = <<-OUTPUT
------------------------------------------------------------------------------------------------------------------------
    REQUEST
    Method:         #{_request.request_method}
    URI:            #{_request.url}

    Host:           #{_request.host}
    Path:           #{_request.path}
    Script Name:    #{_request.script_name}
    Query String:   #{_request.query_string}
    XHR?            #{_request.xhr?}


    Remote
    IP:             #{_request.ip}
    User Agent:     #{_request.user_agent}
    Cookies:        #{_request.cookies}
    Accepts:        #{_request.accept}
    Preferred Type: #{_request.preferred_type}

    Media Type:     #{_request.media_type}
    BODY BEGIN:
#{_request.body.read}
    BODY END.

    Parsed Parameters:
    #{PP.pp(_request.params, '', 60)}

------------------------------------------------------------------------------------------------------------------------
      OUTPUT
      output
    end # request_to_s

    def process_request
      content = params['content']
      return process_callback_type_job_update(content) if content

      job = params['job']
      return process_callback_type_job_save(job) if job
    end # parse_request

    def log_request(route = '')
      logger.debug { "New Request. Via Route: #{route}\n#{request_to_s}" }
    end # log_request

    def process_callback_type_job_update(content_as_json)
      logger.debug { 'Processing Callback of type: job_update' }
      content = JSON.parse(content_as_json)
      job_href = content['href']
      logger.debug { "Job href: #{job_href}"}
      aa.http_get(job_href)

      job = aa.parsed_response
      return unless job
      logger.debug { "ADDING EVENT TO JOB.\n\nJob:\n#{job}\n\nContent:\n#{content}" }
      db.job_add_callback_event(job, content)
      job = process_job(job)

      job
    end # process_callback_type_job_update

    def process_callback_type_job_save(job_json)
      logger.debug { 'Processing Callback of type: job_save' }
      job = JSON.parse(job_json)
      update_job_callback_uri = job['ea:updateJobCallbackURI']
      unless update_job_callback_uri
        before_save_job_type_callback_uri = job['ea:beforeSaveJobTypeCallbackURI']
        logger.debug { "Setting updateJobCallbackURI. #{before_save_job_type_callback_uri}" }
        job['ea:updateJobCallbackURI'] = job['ea:callbackHref'] = before_save_job_type_callback_uri if before_save_job_type_callback_uri
      end
      job_json = JSON.generate(job)
      logger.debug { "RESPONSE BODY: #{job_json}" }
      job_json
    end # process_callback_type_job_save

    def process_job(job)
      @job = job
      job_name = job['jcr:name']
      job_type = job['ea:jobType']
      job_state = job['ea:jobState']
      job_progress = job['ea:progress']

      logger.debug { "Processing Job. name: #{job_name} type: #{job_type} state: #{job_state} progress: #{job_progress}" }

      job_links = job['links']
      self_link_index = job_links.index { |link| link['rel'].downcase == 'self' }
      self_link = job_links[self_link_index]
      self_link_href = self_link['href']

      job_href_info = aa.production_job_href_parse(self_link_href)

      production_id = job_href_info['production_id']
      aa.production_get(production_id)
      @production = aa.parsed_response

      job_parameters = job['ea:parameters']
      job_result = job['ea:result']

      media_paths = job_parameters['mediaPaths']
      case job_type
      #when 'com.adobe.ea.jobs.export'
      # production_href = job_parameters['destination']
      # production_id = href_properties['production_id']
      # production_version = href_properties['production_version']
      #
      when 'com.adobe.ea.jobs.ingest'

        local_media_paths = media_paths.map { |media_path| substitute_path(media_path) }

        @asset_media_information = local_media_paths.map do |local_media_path|
          response = command_line_execute("#{mig_executable_path} '#{local_media_path}'")
          asset_media_info = response[:success] ? JSON.parse(response[:stdout]) : { }
          asset_media_info
        end
        #asset_urls = job['ea:metadata']['ea:retries'][0]['ea:result']['assetURLs']
        #job_metadata = job['ea:metadata'] || { }
        #job_retries = job_metadata['ea:retries'] || [ ]
        #job_retry = job_retries.last || { }
        #job_result = job_retry['ea:result'] || { }
        asset_urls = job_result['assetURLs']
        if asset_urls
        logger.debug { "Processing Asset URL(s): #{asset_urls}" }
          @assets = asset_urls.map do |asset_url|
            aa.http_get(asset_url)
            asset = aa.parsed_response
            logger.debug { "Retrieved Asset Using URL: #{asset_url} RESPONSE: #{asset}" }
            asset
          end
        else
          @assets = [ ]
        end
      #  when 'com.adobe.ea.jobs.productionconversion'
      when 'com.adobe.ea.jobs.transfer'
        aa.production_asset_add(:job_name => "#{job_name}_ingest", :production_id => production_id, :media_paths => media_paths)
      end

      tasks_by_job_type = tasks
      tasks_by_job_state = tasks_by_job_type[job_type] || { }
      task = tasks_by_job_state[job_state] || false

      begin
        process_task(task) if task
      rescue => e
        logger.error { "Exception While Processing Task. #{e.message}\nBACKTRACE:\n #{e.backtrace}" }
      end

      job
    end # process_job


    def process_task(task, params = {})
      task_type = task[:type] ||= :execute

      case task_type
      when :execute; process_task_type_execute(task)
      else
        logger.warn { "Unknown Task Type: #{task_type}" }
      end
    end # process_task

    # @param [String, Symbol] name
    # @param [String] value
    def eval_parameter(name, value)
      return value unless value.is_a?(String)
      logger.debug { "Evaluating Parameter Value: #{value}"}
      begin
        value = eval(value)
      rescue => e
        error_message = "Error Evaluating Parameter#{name ? ": #{name}" : ''}. Message: #{$!}"
        logger.error { error_message }
        raise(e, error_message)
      end
      logger.debug { "Parameter Value Evaluated: #{value}"}
      value
    end # process_task_parameter_eval

    # @param [String] name The name of the parameter being processed. This is used primarily for debugging.
    # @param [Any] parameter
    def process_task_parameter!(name, parameter)
      logger.debug { "Processing Task Parameter#{name ? " Name: #{name}" : ''} Value: #{parameter.inspect}" }
      if parameter.is_a?(Hash) and parameter.has_key?(:value)
        value = parameter[:value]
        value = eval_parameter(name, value) if parameter[:eval]
      else
        value = parameter
      end
      value
    end # process_task_parameter!

    # @param [String] name
    # @param [Any] parameter
    def process_task_parameter(name, parameter)
      parameter = parameter.dup rescue parameter
      return parameter.map { |p| process_task_parameter(name, p) } if parameter.is_a?(Array)
      process_task_parameter!(name, parameter)
    end # process_task_parameter

    def process_task_type_execute(task)
      logger.debug { 'Processing Task of type: execute' }
      #cmd_line_ary = [ ]

      executable_path = search_hash(task, :executable_path, :executable, :exec)
      executable_path = process_task_parameter(:executable_path, executable_path) if executable_path

      #arguments = search_hash(task, :executable_arguments, :arguments)
      #arguments = process_task_parameter(:executable_arguments, arguments) if arguments

      #cmd_line_ary << executable_path if executable_path
      #[*arguments].each { |arg| cmd_line_ary << arg } if arguments

      #cmd_line = cmd_line_ary.shelljoin
      cmd_line = executable_path
      command_line_execute(cmd_line)
    end # process_task_type_execute

    # @param [String, Array<String>] command The command to run
    # @return [Hash] { "STDOUT" => [String], "STDERR" => [String], "STATUS" => [Object] }
    def command_line_execute(command)
      command = command.shelljoin if command.is_a?(Array)

      logger.debug { "Executing Command: #{command}" }
      begin
        stdout_str, stderr_str, status = Open3.capture3(command)
        logger.error { "Error Executing #{command}. STDOUT #{stdout_str} STDERR: #{stderr_str}" } unless status.success?
        return { :stdout => stdout_str, :stderr => stderr_str, :status => status, :success => status.success? }
      rescue
        logger.error { "Error Executing '#{command}'. Exception: #{$!} @ #{$@} STDOUT: '#{stdout_str}' STDERR: '#{stderr_str}' Status: #{status.inspect} " }
        return { :stdout => stdout_str, :stderr => stderr_str, :status => status, :success => false }
      end
    end # command_line_execute

    def substitute_path(path, substitutions = path_substitutions)
      path = path.dup
      substitutions.each { |search_for, replace_with| path = path.sub(search_for, replace_with) if path.start_with?(search_for) }
      path
    end # substitute_path

  end # CallbackMonitor

end # AdobeAnywhere