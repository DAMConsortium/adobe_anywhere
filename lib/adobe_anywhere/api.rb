require 'adobe_anywhere'

module AdobeAnywhere

  class HTTPHandler

    #DEFAULT_HOST_ADDRESS = AdobeAnywhere::DEFAULT_HOST_ADDRESS
    #DEFAULT_PORT = AdobeAnywhere::DEFAULT_PORT

    attr_accessor :logger, :log_request_body, :log_response_body, :log_pretty_print_body

    attr_reader :http

    attr_accessor :cookie

    # @param [Hash] params
    # @option params [Logger] :logger
    # @option params [String] :log_to
    # @option params [Integer] :log_level
    # @option params [String] :host_address
    # @option params [Integer] :port
    def initialize(params = {})
      @logger = params[:logger] ? params[:logger].dup : Logger.new(params[:log_to] || STDOUT)
      logger.level = params[:log_level] if params[:log_level]

      hostname = params[:host_address] || DEFAULT_HOST_ADDRESS
      port = params[:port] || DEFAULT_PORT
      @http = Net::HTTP.new(hostname, port)
      @log_request_body = params[:log_request_body]
      @log_response_body = params[:log_response_body]
      @log_pretty_print_body = params[:log_pretty_print_body]
    end # initialize

    def http=(new_http)
      @to_s = nil
      @http = new_http
    end # http=

    # Formats a HTTPRequest or HTTPResponse body for log output.
    # @param [HTTPRequest|HTTPResponse] obj
    # @return [String]
    def format_body_for_log_output(obj)
      #obj.body.inspect
      output = ''
      if obj.content_type == 'application/json'
        if @log_pretty_print_body
          output << "\n"
          output << JSON.pretty_generate(JSON.parse(obj.body))
          return output
        else
          return obj.body
        end
      else
        return obj.body.inspect
      end
    end # pretty_print_body

    # Performs final processing of a request then executes the request and returns the response.
    #
    # Debug output for all requests and responses is also handled by this method.
    # @param [HTTPRequest] request
    def process_request(request)
      request['Cookie'] = cookie if cookie
      logger.debug { redact_passwords(%(REQUEST: #{request.method} #{to_s}#{request.path} HEADERS: #{request.to_hash.inspect} #{log_request_body and request.request_body_permitted? ? "BODY: #{format_body_for_log_output(request)}" : ''})) }

      #TODO LOOKUP REQUEST E-TAG

      response = http.request(request)
      logger.debug { %(RESPONSE: #{response.inspect} HEADERS: #{response.to_hash.inspect} #{log_response_body and response.respond_to?(:body) ? "BODY: #{format_body_for_log_output(response)}" : ''}) }

      #TODO PROCESS ETAG RELATED RESPONSES (304 ?and 412?)

      #TODO RECORD RESPONSE E-TAG

      response
    end # process_request

    # Creates a HTTP DELETE request and passes it to {#process_request} for final processing and execution.
    # @param [String] path
    # @param [Hash] headers
    def delete(path, headers)
      http_to_s = to_s
      path = path.sub(http_to_s) if path.start_with?(http_to_s)
      path = "/#{path}" unless path.start_with?('/')
      request = Net::HTTP::Delete.new(path, headers)
      process_request(request)
    end # delete

    # Creates a HTTP GET request and passes it to {#process_request} for final processing and execution.
    # @param [String] path
    # @param [Hash] headers
    def get(path, headers)
      http_to_s = to_s
      path = path.sub(http_to_s, '') if path.start_with?(http_to_s)
      path = "/#{path}" unless path.start_with?('/')
      request = Net::HTTP::Get.new(path, headers)
      process_request(request)
    end # get

    # Processes put and post request bodies based on the request content type and the format of the data
    # @param [HTTPRequest] request
    # @param [Hash|String] data
    def process_put_and_post_requests(request, data)
      content_type = request['Content-Type'] ||= 'application/x-www-form-urlencoded'
      if data.is_a?(Hash)
        case content_type
        when 'application/x-www-form-urlencoded'; request.form_data = data
        when 'application/json'; request.body = JSON.generate(data)
        end
      else
        #data = data.to_s unless request.body.is_a?(String)
        request.body = data
      end
      process_request(request)
    end # process_form_request

    # Creates a HTTP POST request and passes it on for execution
    # @param [String] path
    # @param [String|Hash] data
    # @param [Hash] headers
    def post(path, data, headers)
      path = "/#{path}" unless path.start_with?('/')
      request = Net::HTTP::Post.new(path, headers)
      process_put_and_post_requests(request, data)
    end # post

    # Creates a HTTP PUT request and passes it on for execution
    # @param [String] path
    # @param [String|Hash] data
    # @param [Hash] headers
    def put(path, data, headers)
      path = "/#{path}" unless path.start_with?('/')
      request = Net::HTTP::Put.new(path, headers)
      process_put_and_post_requests(request, data)
    end # post

    #def post_form_multipart(path, data, headers)
    #  #headers['Cookie'] = cookie if cookie
    #  #path = "/#{path}" unless path.start_with?('/')
    #  #request = Net::HTTP::Post.new(path, headers)
    #  #request.body = data
    #  #process_request(request)
    #end # post_form_multipart

    # Looks for passwords in a string and redacts them.
    #
    # @param [String] string
    # @return [String]
    def redact_passwords(string)
      string.sub!(/password((=.*)(&|$)|("\s*:\s*".*")(,|\s*|$))/) do |s|
        if s.start_with?('password=')
          _, remaining_string = s.split('&', 2)
          password_mask       = "password=*REDACTED*#{remaining_string ? "&#{redact_passwords(remaining_string)}" : ''}"
        else
          _, remaining_string = s.split('",', 2)
          password_mask       = %(password":"*REDACTED*#{remaining_string ? %(",#{redact_passwords(remaining_string)}) : '"'})
        end
        password_mask
      end
      string
    end # redact_passwords

    # Returns the connection information in a URI format.
    # @return [String]
    def to_s
      @to_s ||= "http#{http.use_ssl? ? 's' : ''}://#{http.address}:#{http.port}"
    end # to_s

  end # HTTPHandler

  class API

    attr_accessor :logger, :http, :response, :identity, :parse_response, :error

    class HTMLResponseParser

      def self.parse(text)
        new(text)
      end # parse

      def initialize(text)
        @raw_text = text
        @attributes = { }

        m = text.match(/\s*<title>(.*)<\/title>/)
        @attributes[:title] = m[1] if m

        m = text.match(/\s*<div id="Status">(.*)<\/div>/)
        @attributes[:status] = m[1] if m

        m = text.match(/\s*<div id="Message">(.*)<\/div>/)
        @attributes[:message] = m[1] if m

        m = text.match(/\s*<div id="Path">(.*)<\/div>/)
        @attributes[:path] = m[1] if m
      end # initialize

      def [](key)
        key = key.to_sym rescue key
        @attributes[key]
      end # []

      # @return [String]
      def to_s
        return "#{@attributes[:status]} #{@attributes[:title]} message=#{@attributes[:message]}" unless @attributes.empty?
        @raw_text
      end # to_s
      alias :inspect :to_s

      # @return [Hash]
      def to_hash
        @attributes
      end # to_hash

    end # HTMLResponseParser

    # @param [Hash] params
    # @option params [Logger] :logger
    # @option params [String] :log_to
    # @option params [Integer] :log_level
    # @option params [Boolean] :parse_response (false)
    def initialize(params = {})
      @logger = params[:logger] ? params[:logger].dup : Logger.new(params[:log_to] || STDOUT)
      @logger.level = params[:log_level] if params[:log_level]

      @parse_response = params[:parse_response]

      initialize_http_handler(params)
    end # initialize

    # Sets the AdobeAnywhere connection information.
    # @see HTTPHandler#new
    def initialize_http_handler(params = {})
      @http = HTTPHandler.new(params)
      logger.debug { "Connection Set: #{http.to_s}" }
    end # connect

    # Returns the stored cookie information
    # @return [String]
    def http_cookie
      http.cookie
    end # http_cookie

    # Sets the cookie information that will be used with subsequent calls to the HTTP server.
    # @param [String] content
    def http_cookie=(content)
      logger.debug { content ? "Setting Cookie: #{content}" : 'Clearing Cookie' }
      http.cookie = content
    end # http_cookie=

    # Executes a HTTP DELETE request
    # @param [String] path
    # @param [Hash] headers
    # @return [String|Hash] If parse_response? is true then there will be an attempt to parse the response body based on
    # it's content type. If content type is not support then the respond body is returned.
    #
    # If parse_response? is false then the response body is returned.
    def http_delete(path, headers = {})
      clear_response
      @success_code = 204
      @response = http.delete(path, headers)
      parse_response? ? parsed_response : response.body
    end # http_delete

    # Executes a HTTP GET request and returns the response
    # @param [String] path
    # @param [Hash] headers
    # @return [String|Hash] If parse_response? is true then there will be an attempt to parse the response body based on
    # it's content type. If content type is not support then the respond body is returned.
    #
    # If parse_response? is false then the response body is returned.
    def http_get(path, headers = { })
      clear_response
      @success_code = 200
      @response = http.get(path, headers)
      parse_response? ? parsed_response : response.body
    end # http_get

    # Executes a HTTP POST request
    # @param [String] path
    # @param [String] data
    # @param [Hash] headers
    # @return [String|Hash] If parse_response? is true then there will be an attempt to parse the response body based on
    # it's content type. If content type is not support then the respond body is returned.
    #
    # If parse_response? is false then the response body is returned.
    def http_post(path, data, headers = {})
      clear_response
      @success_code = 201
      @response = http.post(path, data, headers)
      parse_response? ? parsed_response : response.body
    end # http_post

    # Formats data as form url encoded and calls {#http_post}
    # @param [String] path
    # @param [Hash] data
    # @param [Hash] headers
    # @return [String|Hash] If parse_response? is true then there will be an attempt to parse the response body based on
    # it's content type. If content type is not support then the respond body is returned.
    #
    # If parse_response? is false then the response body is returned.
    def http_post_form(path, data, headers = {})
      headers['Content-Type'] = 'application/x-www-form-urlencoded'
      #data_as_string = URI.encode_www_form(data)
      #post(path, data_as_string, headers)
      clear_response
      @success_code = 201
      @response = http.post(path, data, headers)
      parse_response? ? parsed_response : response.body
    end # http_post_form

    # Formats data as JSON and calls {#http_put}
    # @param [String] path
    # @param [Hash] data
    # @param [Hash] headers
    # @return [String|Hash] If parse_response? is true then there will be an attempt to parse the response body based on
    # it's content type. If content type is not support then the respond body is returned.
    #
    # If parse_response? is false then the response body is returned.
    def http_post_json(path, data, headers = {})
      headers['Content-Type'] = 'application/json'
      data_as_string = JSON.generate(data)
      http_post(path, data_as_string, headers)
    end # http_post_json

    #def http_post_form_multipart(path, data, headers = { })
    #  headers['Content-Type'] = 'multipart/form-data'
    #
    #end # http_post_form_multipart


    # Executes a HTTP PUT request
    # @param [String] path
    # @param [String] data
    # @param [Hash] headers
    # @return [String|Hash] If parse_response? is true then there will be an attempt to parse the response body based on
    # it's content type. If content type is not support then the respond body is returned.
    #
    # If parse_response? is false then the response body is returned.
    def http_put(path, data, headers = {})
      clear_response
      @success_code = 200
      @response = http.put(path, data, headers)
      parse_response? ? parsed_response : response.body
    end # http_put

    # Formats data as JSON and calls {#http_put}
    def http_put_json(path, data, headers = { })
      headers['Content-Type'] = 'application/json'
      data_as_string = JSON.generate(data)
      http_put(path, data_as_string, headers)
    end # put_json


    # The http response code that indicates success for the request being made.
    def success_code
      @success_code
    end # success_code
    private :success_code

    # Returns true if the response code equals the success code that was set by the method.
    def success?
      return nil unless @success_code
      response.code == @success_code.to_s
    end # success?

    def clear_response
      @error = { }
      @success_code = @response = @parsed_response = nil
    end # clear_response
    private :clear_response

    # Returns true if the response body parsing option has been set to true.
    def parse_response?
      parse_response
    end # parse_response?
    private :parse_response?

    # Parses the response body based on the response's content-type header value
    # @return [nil|String|Hash]
    #
    # Will pass through the response body unless the content type is supported.
    def parsed_response
      #logger.debug { "Parsing Response: #{response.content_type}" }
      @parsed_response ||= case response.content_type
                             when 'application/json'; JSON.parse(response.body)
                             when 'text/html'; HTMLResponseParser.parse(response.body)
                             else; response.to_hash
                           end
      @parsed_response
    end # parsed_response

    # @param [String] url
    # @return [Hash]
    def production_href_parse(url)
      #m = url.match(/(?<protocol>.*):\/\/(?<host_info>.*)\/content\/ea\/git\/productions\/(?<production_id>.*)\/(?<production_version>.*)\.v1\.json/)
      #href_properties = m ? Hash[m.names.zip(m.captures)] : { }
      #href_properties
      m = url.match(/(.*):\/\/(.*)\/content\/ea\/git\/productions\/(.*)\/(.*)\.v1\.json/)
      href_properties = m ? {
        'host_info' => $1,
        'production_id' => $2,
        'production_version' => $3
      } : { }
      href_properties
    end # production_href_parse

    def production_job_href_parse(url)
      #m = url.match(/(?<protocol>.*):\/\/(?<host_info>.*)\/content\/ea\/api\/productions\/(?<production_id>.*)\/jobs\/(?<job_type>.*)\/(?<job_name>.*)\.v1\.json/)
      #href_properties = m ? Hash[m.names.zip(m.captures)] : { }
      #href_properties
      m = url.match(/(.*):\/\/(.*)\/content\/ea\/api\/productions\/(.*)\/jobs\/(.*)\/(.*)\.v1\.json/)
      href_properties = m ? {
        'host_info' => $1,
        'production_id' => $2,
        'job_type' => $3,
        'job_name' => $4,
      } : { }
      href_properties
    end # production_job_href_parse


    ##################################################################################################################
    # API METHODS

    # Login.
    # @param [Hash] params
    # @option params [String] :username
    # @option params [String] :password
    # @return [String] The contents of the set-cookie header
    def login(params = {})
      self.http_cookie = nil
      data = { }

      username = params[:username]
      password = params[:password]

      unless username || password
        username = DEFAULT_USERNAME
        password = DEFAULT_PASSWORD
      end

      data['j_password'] = password if password
      data['j_username'] = username if username

      logger.debug { "Logging In As User: '#{username}' Using Password: #{password ? 'yes' : 'no'}" }
      http_post_form('app/ea/j_security_check?resource=/content/ea/api/discovery.v1.json', data)
      self.http_cookie = response['set-cookie'] if response.code == '302'
      http_cookie
    end # login

    # Logout.
    def logout
      http_get('system/sling/logout?resource=/content/ea/api/discovery.v1.json')
    end # logout

    # List Enclosures
    def enclosure_list
      http_get('content/ea/api/enclosures.v1.json')
    end # enclosure_list


    # Creates an export preset.
    # @param [Hash] params
    # @option params [String] :name REQUIRED
    # @option params [String] :file_name
    # @option params [String] :file_contents
    def export_preset_create(params = {})
      name = params[:name]
      file_contents = params[:file_contents]
      file_name = params[:file_name]

      file_contents ||= File.read(file_name)

      data = { }
      data[':name'] = name
      data[':enclosure'] = file_contents
      http_post_form('content/ea/api/exportpresets.v1.json', data)
    end # export_preset_create
    alias :export_presets_create :export_preset_create

    # Deletes an export preset.
    # @param [String] export_preset_name
    def export_preset_delete(export_preset_name)
      http_delete("content/ea/api/exportpresets/#{export_preset_name.downcase}")
    end # export_preset_delete

    # Lists export presets.
    def export_preset_list
      http_get('content/ea/api/exportpresets.v1.json')
    end # export_preset_list
    alias :export_presets_list :export_preset_list

    # Processes the common job parameters and executes the job post.
    # @param [String] path
    # @param [Hash] params
    # @option params [String] :job_name
    # @option params [String] :update_job_callback_uri
    def job_create(path, params = {})
      params = params.dup

      job_parameters = search_hash!(params, :job_parameters)
      job_name = search_hash!(params, :job_name, :jobName, :jobname, :name)
      update_job_callback_uri = search_hash!(params, :update_job_callback_uri, :updateJobCallbackURI, :updatejobcallbackuri)

      data = { }
      data[':name'] = job_name if job_name
      data[':updateJobCallbackURI'] = update_job_callback_uri if update_job_callback_uri
      data[':parameters'] = job_parameters

      #http_post_form_multipart(path, data)
      http_post_form(path, data)
    end # job_create

    # Creates an ingest job.
    # @param [Hash] params
    # @option params [String, Array<String>] :production_id
    # @option params [String] :production_version ('HEAD')
    # @option params [String] :destination
    # @option params [String, Array<String>] :media_paths
    # @option params [String] :comment
    # @return [String, False] Returns the name of the job or false if a job was not created.
    def job_ingest_create(params = {})
      params = params.dup
      production_id = search_hash!(params, :production_id, :productionId, :productionid)
      return production_id.map { |cp_id| job_ingest_create(params.merge(:production_id => cp_id)) } if production_id.is_a?(Array)

      production_version = search_hash!(params, :production_version, :version, :commit_id, :commit, :commitid) || 'HEAD'

      destination = search_hash!(params, :destination)
      destination ||= "#{http.to_s}/content/ea/git/productions/#{production_id}/#{production_version}.v1.json"

      media_paths = search_hash!(params, :media_paths, :mediaPaths)
      comment = search_hash!(params, :comment)

      job_parameters = { }

      job_parameters['destination'] = destination
      job_parameters['mediaPaths'] = [*media_paths] if media_paths
      job_parameters['comment'] = comment if comment

      params[:job_parameters] = JSON.generate(job_parameters)
      job_create("content/ea/api/productions/#{production_id}/jobs/ingest.v1.json", params)
      return parsed_response['jcr:name'] if success?
      false
    end # job_ingest_create

    # Lists jobs
    # @param [String] type (nil) Known types are SUCCESSFUL, WAITING, SCHEDULED, FAILED, RUNNING, CANCELED, CANCEL
    def job_list(type = nil)
      path = 'content/ea/api/jobs.v1.json'
      path << '/' << type.upcase if type
      http_get(path)
    end # job_list
    alias :jobs_list :job_list

    # List Available Job Types
    def job_list_job_types
      http_get('content/ea/api/jobs.type.v1.json')
    end # job_list_job_types

    # List Medialocators
    def medialocator_list
      http_get('content/ea/api/medialocators.v1.json')
    end # medialocator_list

    # List Monitors
    def monitor_list
      http_get('content/ea/api/monitors.v1.json')
    end # monitor_list

    # List Mount Point Labels
    def mount_point_lable_list(params = {})
      http_get('content/ea/api/mountpointlabels.v1.json')
    end # mount_point_lable_list

    # List Node Controllers
    def node_controller_list
      http_get('content/ea/api/nodecontrollers.v1.json')
    end # node_controller_list

    # Node Controller Status
    def node_controller_status
      http_get('content/ea/api/nodecontroller/status.json')
    end # node_controller_status


    # Creates a Production Conversion Job
    # @param [Hash] params
    # @option params [String] :production_id
    # @option params [String] :production_url
    def job_production_conversion_create(params = {})
      #{"productionURL":"http://10.42.1.109:60138/content/ea/git/productions/45499fcd-6db1-4e77-ad68-ccfeb2ab34b9/HEAD.v1.json?1375708498312&1375712207416&1375712213012","destinationPath":"eamedia://media/test pcj ","productionConverterType":"AAF"}

      params = params.dup

      production_id = search_hash!(params, :production_id, :productionId, :productionid, :id)
      production_url = search_hash!(params, :production_url, :productionURL, :productionurl, :url)
      production_url ||= File.join(http.to_s, "content/ea/git/productions/#{production_id}/HEAD.v1.json")
      destination_path = search_hash!(params, :destination_path, :destinationPath, :destinationpath, :destination)
      production_converter_type = search_hash!(params, :production_converter_type, :productionConverterType, :productionconvertertype, :type)

      job_parameters = { }
      job_parameters['productionURL'] = production_url
      job_parameters['productionConverterType'] = production_converter_type
      #job_parameters['destinationPath'] = destination_path
      job_parameters['destination'] = destination_path

      params[:job_parameters] = JSON.generate(job_parameters)
      job_create("content/ea/api/productions/#{production_id}/jobs/productionconversion.v1.json", params)
      return parsed_response['jcr:name'] if success?
      false
    end # job_production_conversion_create

    # Creates a production.
    # @param [Hash] params
    # @option params [String] name
    # @option params [String] description
    # custom json properties may be added to the request and will be stored on the server with the production
    def production_create(params = {})
      params = params.dup
      params['name'] = search_hash!(params, :name, :production_name)
      params['description'] = search_hash!(params, :description, :production_description)
      http_post_json('content/ea/git/productions.v1.json', params)
    end # production_create

    def production_get(production_id, production_version = 'HEAD')
      http_get("content/ea/git/productions/#{production_id}/#{production_version}.v1.json")
    end # production_get

    # Lists productions
    def production_list
      http_get('content/ea/git/productions.v1.json')
    end # production_list
    alias :productions_list :production_list

    def production_asset_delete(etag)
      #params = params.dup
      #production_id = search_hash!(params, :production_id, :productionId, :productionid)
      #production_version = search_hash!(params, :production_version, :productionVersion, :productionversion, :version) || 'HEAD'
      ##e_tag = search_hash!(params, :e_tag, :ETag, :eTag, :etag)
      ##delete("content/ea/git/productions/#{production_id}/HEAD.v1.json", { 'If-Match' => e_tag })
      #delete("content/ea/git/productions/#{production_id}/#{production_version}.v1.json")
      #return true if response.code == 204
      #false
    end # production_asset_delete

    # Lists the assets of a production
    def production_asset_list(production_id)
      http_get("content/ea/git/productions/#{production_id}/HEAD/assets.v1.json")
    end # production_asset_list

    # Deletes a production.
    # @param [Hash] params
    # @option params [String] :production_id
    # @option parmas []
    def production_delete(params = {})
      params = params.dup
      production_id = search_hash!(params, :production_id, :productionId, :productionid, :id)
      production_version = search_hash!(params, :production_version, :productionVersion, :productionversion, :version) || 'HEAD'
      #e_tag = search_hash!(params, :e_tag, :ETag, :eTag, :etag)
      #delete("content/ea/git/productions/#{production_id}/HEAD.v1.json", { 'If-Match' => e_tag })
      http_delete("content/ea/git/productions/#{production_id}/#{production_version}.v1.json")
      #return true if response.code == 204
      #false
    end # production_delete

    # Creates a new production asset export job.
    # @param [Hash] params
    # @option params [String] :production_id
    # @option params [String] :exporter_preset
    # @option params [String] :destination_path
    # @option params [String] :asset_url
    # @return [String, false] The job URI if the job was created, false otherwise.
    def production_export_asset(params = {})
      params = params.dup

      production_id = search_hash(params, :production_id, :productionId, :productionid)
      exporter_preset = search_hash!(params, :exporter_preset, :exporterPreset, :exporterpreset)
      destination_path = search_hash!(params, :destination_path, :destinationPath, :destinationpath)
      asset_url = search_hash!(params, :asset_url, :assetURL, :asseturl)

      logger.debug { "Creating Production Asset Export Job. #{production_id} #{exporter_preset} #{asset_url} #{destination_path}"}

      job_parameters = { }

      job_parameters['exporterPreset'] = exporter_preset
      job_parameters['assetURL'] = asset_url
      job_parameters['destinationPath'] = destination_path

      params[:job_parameters] = JSON.generate(job_parameters)
      job_create("content/ea/api/productions/#{production_id}/jobs/export.v1.json", params)
      #return response['location'].first if successful?
      #false
    end # production_export_asset

    # Lists jobs associated with a specific production.
    # @param [String] production_id REQUIRED
    def production_job_list(production_id)
      http_get("content/ea/api/productions/#{production_id}/jobs.v1.json")
    end # production_job_list

    # Creates a session.
    # @param [Hash] params
    # @option params [String] :production_id REQUIRED
    # @option params [Boolean|String] :is_temporary
    def production_session_create(params = {})
      data = { }
      production_id = search_hash(params, :production_id, :productionId, :productionid)
      is_temporary = search_hash(params, :is_temporary, :isTemporary, :istemporary)
      data['isTemporary'] = is_temporary if is_temporary
      http_post_form("content/ea/git/productions/#{production_id}/HEAD.sessions.v1.json", data)
    end # production_session_create

    # Retrieves a user's information using the user id.
    # @param [String] user_id
    def user_by_user_id(user_id)
      return user_id.map { |uid| user_by_user_id(uid) } if user_id.is_a?(Array)
      http_get("content/ea/api/users.byUserId.v1.json/#{user_id}")
    end # user_by_user_id

    # Lists users.
    def user_list
      http_get('content/ea/api/users.v1.json')
    end # user_list
    alias :users_list :user_list

  end # API

end # AdobeAnywhere