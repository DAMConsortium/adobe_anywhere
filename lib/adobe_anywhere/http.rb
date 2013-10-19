require 'sinatra/base'
require 'adobe_anywhere/api/utilities'
module AdobeAnywhere

  class HTTP < Sinatra::Base

    enable :logging
    disable :protection

    def self.init(args = { })
      args.each { |k,v| set(k, v) }

      def logger; settings.logger end if settings.logger
    end # new

    def format_response(response, args = { })
      supported_types = [ 'application/json', 'application/xml', 'text/xml' ]
      case request.preferred_type(supported_types)
        when 'application/json'
          content_type :json
          _response = response.is_a?(Hash) || response.is_a?(Array) ? JSON.generate(response) : response
        #when 'application/xml', 'text/xml'
        #  content_type :xml
        #  _response = XmlSimple.xml_out(response, { :root_name => 'response' })
        else
          content_type :json
          _response = response.is_a?(Hash) || response.is_a?(Array) ? JSON.generate(response) : response
      end
      _response
    end # output_response


    # Will try to convert a body to parameters and merge them into the params hash
    # Params will override the body parameters
    #
    # @params [Hash] _params (params) The parameters parsed from the query and form fields
    def merge_params_from_body(_params = params)
      _params = _params.dup
      if request.media_type == 'application/json'
        request.body.rewind
        body_contents = request.body.read
        logger.debug { "Parsing: '#{body_contents}'" }
        if body_contents
          json_params = JSON.parse(body_contents)
          if json_params.is_a?(Hash)
            #json_params = indifferent_hash.merge(json_params)
            _params = json_params.merge(_params)
          else
            _params['body'] = json_params
          end
        end
      end
      indifferent_hash.merge(_params)
    end # merge_params_from_body

    post '/api' do
      _params = params.dup
      _params = merge_params_from_body(_params)

      aa_args = { :logger => settings.logger }
      aa_args[:host_address] = search_hash!(_params, :host_address) || settings.anywhere_default_host_address
      aa_args[:port] = search_hash!(_params, :port) || settings.anywhere_default_host_port
      aa_args[:username] = search_hash!(_params, :username) || settings.anywhere_default_username
      aa_args[:password] = search_hash!(_params, :password) || settings.anywhere_default_password
      #logger.debug { "AA Args: #{aa_args}" }
      begin
        aa = AdobeAnywhere::API::Utilities.new(aa_args)
        aa.login
      rescue => e
        logger.warn { "Exception While Logging into Anywhere. #{e.message}\nBacktrace:\n#{e.backtrace}" }
        return format_response({ :exception => { :message => e.message, :backtrace => e.backtrace } })
      end

      method_name = search_hash!(_params, :method_name, :method, :command, :procedure)
      return format_response({ :error => { :message => ':method_name is a required argument.' } }) unless method_name

      method_name = method_name.sub('-', '_').to_sym
      method_arguments = search_hash!(_params, :arguments)
      method_arguments = JSON.parse(method_arguments) rescue method_arguments if method_arguments.is_a?(String)
      logger.debug { "\nMethod Name: #{method_name}\nArguments: #{method_arguments}" }

      send_args = [ method_name ]
      send_args << method_arguments if method_arguments
      @safe_methods ||= aa.methods - Object.new.methods
      if @safe_methods.include?(method_name)
        begin
          _response = aa.send(*send_args)
        rescue => e
          logger.warn { "Error executing api command. #{e.message}\nBacktrace:\n#{e.backtrace}" }
          _response = { :exception => { :message => e.message, :backtrace => e.backtrace } }
        end
      else
        _response = { :error => "#{method_name} is not a valid method name." }
      end
      logger.debug { "Response: #{_response}" }
      format_response(_response)
    end

  end # HTTP

end # AdobeAnywhere