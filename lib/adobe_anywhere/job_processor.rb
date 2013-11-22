require 'open3'

module AdobeAnywhere

  class JobProcessor

    ###################################

    attr_accessor :logger

    attr_accessor :aa

    attr_accessor :db

    attr_accessor :path_substitutions

    attr_accessor :mig_executable_path

    ####################################

    attr_accessor :tasks

    attr_accessor :job

    attr_accessor :production

    attr_accessor :assets

    attr_accessor :asset_media_information

    def initialize(args = {})

      initialize_logger(args)
      logger.debug { 'Initializing Job Processor.' }


      load_configuration_from_file(args[:config_file_path])
      @tasks ||= { }
      @path_substitutions ||= { }

      logger.debug { "Tasks: #{@tasks}" }
      logger.debug { "Path Substitutions: #{@path_substitutions}" }

      @mig_executable_path = args[:mig_executable_path]
      if mig_executable_path
        if File.executable?(mig_executable_path)
          logger.debug { "M.I.G. Executable Found. #{mig_executable_path}" }
        else
          logger.warn { "MIG DISABLED. FILE NOT #{File.exists?(mig_executable_path) ? 'EXECUTABLE' : 'FOUND'}. '#{mig_executable_path}'" }
          @mig_executable_path = false
        end
      end
      @ingest_asset_on_transfer = args.fetch(:trigger_asset_ingest_on_transfer, false)

      logger.debug { 'Job Processor Initialized.' }
    end # initialize

    def initialize_logger(args = {})
      @logger = args[:logger] || Logger.new(args[:log_to] || STDOUT)
      logger.level = args[:log_level] if args[:log_level]
      args[:logger] ||= logger
      logger
    end # initialize_logger


    def load_configuration_from_file(file_path)
      eval(File.read(file_path)) if file_path
    end # load_configuration_from_file

    def mig(file_path)
      return file_path.map { |p| mig(p) } if file_path.is_a?(Array)
      return { } unless mig_executable_path

      local_file_path = substitute_path(file_path)
      logger.debug { "Running MIG on path: LOCAL: '#{local_file_path}' REMOTE: '#{file_path}'" }
      response = command_line_execute("#{mig_executable_path} '#{local_file_path}'")
      asset_media_info = response[:success] ? JSON.parse(response[:stdout]) : { }
      asset_media_info
    end


    def process_job(job, params = {})
      @production = @assets = @asset_media_information = nil

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

      job = aa.http_get(self_link_href) unless job.has_key?('ea:parameters')

      job_href_info = aa.production_job_href_parse(self_link_href)

      production_id = job_href_info['production_id']
      aa.production_get(production_id)
      @production = aa.parsed_response

      job_parameters = job['ea:parameters'] || { }
      job_result = job['ea:result']

      media_paths = job_parameters['mediaPaths']
      case job_type
        #when 'com.adobe.ea.jobs.export'
        # production_href = job_parameters['destination']
        # production_id = href_properties['production_id']
        # production_version = href_properties['production_version']
        #
        when 'com.adobe.ea.jobs.ingest'
          @asset_media_information = mig(media_paths) if media_paths

          #asset_urls = job['ea:metadata']['ea:retries'][0]['ea:result']['assetURLs']
          #job_metadata = job['ea:metadata'] || { }
          #job_retries = job_metadata['ea:retries'] || [ ]
          #job_retry = job_retries.last || { }
          #job_result = job_retry['ea:result'] || { }
          @assets = [ ]
          if job_result
            asset_urls = job_result['assetURLs']
            if asset_urls
              logger.debug { "Processing Asset URL(s): #{asset_urls}" }
              @assets = asset_urls.map do |asset_url|
                aa.http_get(asset_url)
                asset = aa.parsed_response
                logger.debug { "Retrieved Asset Using URL: #{asset_url} RESPONSE: #{asset}" }
                asset
              end
            end
          end
        #  when 'com.adobe.ea.jobs.productionconversion'
        when 'com.adobe.ea.jobs.transfer'
          aa.production_asset_add(:job_name => "#{job_name}_ingest", :production_id => production_id, :media_paths => media_paths) if @ingest_asset_on_transfer

          if job_state == 'SUCCESSFUL'
            files = job_parameters['files']
            file_paths = files.is_a?(Array) ? files.map { |f| f['dest' ] } : [ ]
            @asset_media_information = mig(file_paths)
          end
          #abort("JOB STATE: #{job_state}")
      end
      #abort("JOB TYPE: #{job_type}")
      if tasks
        tasks_by_job_type = tasks
        tasks_by_job_state = tasks_by_job_type[job_type] || { }
        task = tasks_by_job_state[job_state] || false

        begin
          process_task(task) if task
        rescue => e
          logger.error { "Exception While Processing Task. #{e.message}\nBACKTRACE:\n #{e.backtrace}" }
        end
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

    # @param [Hash] task
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

    # @param [String] path
    # @param [Hash] substitutions
    def substitute_path(path, substitutions = path_substitutions)
      path = path.dup
      substitutions.each { |search_for, replace_with| path = path.sub(search_for, replace_with) if path.start_with?(search_for) }
      path
    end # substitute_path

  end # JobProcessor

end # AdobeAnywhere