require 'adobe_anywhere/cli'
require 'adobe_anywhere/api/utilities'
module AdobeAnywhere

  class API

    class Utilities

      class CLI < AdobeAnywhere::CLI

        attr_accessor :aa

        def parse_options
          options = AdobeAnywhere::API.default_options.merge({
            :log_to => STDERR,
            :log_level => Logger::WARN,
            :options_file_path => File.expand_path(File.basename($0, '.*'), '~/.options'),
          })
          op = OptionParser.new
          op.on('--host-address HOSTADDRESS', 'The AdobeAnywhere server address.',
                "\tdefault: #{options[:host_address]}") { |v| options[:host_address] = v }
          op.on('--port PORT', 'The port on the AdobeAnywhere server to connect to.',
                "\tdefault: #{options[:port]}") { |v| options[:port] = v }
          op.on('--username USERNAME', 'The username to login with. This will be ignored if cookie contents is set and the force login parameter is false.',
                "\tdefault: #{options[:username]}") { |v| options[:username] = v }
          op.on('--password PASSWORD', 'The password to login with. This will be ignored if cookie contents is set and the force login parameter is false.',
                "\tdefault: #{options[:password]}") { |v| options[:password] = v }
          op.on('--force-login', 'Forces a new cookie even if cookie information is present.') { |v| options[:force_login] = v }
          op.on('--method-name METHODNAME', '') { |v| options[:method_name] = v }
          op.on('--method-arguments JSON', '') { |v| options[:method_arguments] = v }
          op.on('--pretty-print', '') { |v| options[:pretty_print] = v }
          op.on('--cookie-contents CONTENTS', 'Sets the cookie contents.') { |v| options[:cookie_contents] = v }
          op.on('--cookie-file-name FILENAME',
                'Sets the cookie contents from the contents of a file.') { |v| options[:cookie_file_name] = v }
          op.on('--set-cookie-env',
                "Saves cookie contents to an environmental variable named #{AdobeAnywhere::ENV_VAR_NAME_ADOBE_ANYWHERE_COOKIE}") do |v|
            options[:set_cookie_env_var] = v
          end
          op.on('--set-cookie-file FILENAME', 'Saves cookie contents to a file.') { |v| options[:set_cookie_file_name] = v }
          op.on('--log-to FILENAME', 'Log file location.', "\tdefault: STDERR") { |v| options[:log_to] = v }
          op.on('--log-level LEVEL', LOGGING_LEVELS.keys, "Logging level. Available Options: #{LOGGING_LEVELS.keys.join(', ')}",
                "\tdefault: #{LOGGING_LEVELS.invert[options[:log_level]]}") { |v| options[:log_level] = LOGGING_LEVELS[v] }
          op.on('--[no-]options-file [FILENAME]', 'Path to a file which contains default command line arguments.', "\tdefault: #{options[:options_file_path]}" ) { |v| options[:options_file_path] = v}
          op.on_tail('-h', '--help', 'Show this message.') { puts op; exit }
          op.parse!(ARGV.dup)

          options_file_path = options[:options_file_path]
          # Make sure that options from the command line override those from the options file
          op.parse!(ARGV.dup) if op.load(options_file_path)
          options
        end # parse_options


        def initialize(params = {})
          params = parse_options.merge(params)
          @logger = Logger.new(params[:log_to])
          logger.level = params[:log_level] if params[:log_level]
          params[:logger] = logger

          @aa = AdobeAnywhere::API::Utilities.new(params)

          ## LIST METHODS
              #methods = aa.methods; methods -= Object.methods; methods.sort.each { |method| puts "#{method} #{aa.method(method).parameters}" }; exit

          params[:cookie_contents] = File.read(params[:cookie_file_name]) if params[:cookie_file_name]
          aa.http_cookie = cookie_contents = params[:cookie_contents] if params[:cookie_contents]
          aa.http.log_request_body = true
          aa.http.log_response_body = true
          aa.http.log_pretty_print_body = true

          begin
            cookie_contents = aa.login(params) unless cookie_contents && !params[:force_login]
          rescue => e
            abort "Error performing login on #{aa.http.to_s}. #{e.message}"
          end

          if cookie_contents
            #logger.debug { "Cookie Contents Set: #{cookie_contents}" }
            ENV[ENV_VAR_NAME_ADOBE_ANYWHERE_COOKIE] = cookie_contents if params[:set_cookie_env_var]
            File.write(params[:set_cookie_file_name], cookie_contents) if params[:set_cookie_file_name]
          end #

          method_name = params[:method_name]
          send(method_name, params[:method_arguments], :pretty_print => params[:pretty_print]) if method_name

        end # initialize

        class ResponseHandler

          class << self

            attr_accessor :aa

            attr_accessor :response

            def group_create(*args)
              m = aa.response.body.match(/<title>(.*)<\/title>/)
              $1
            end # group_create

            def user_create(*args)
              m = aa.response.body.match(/<title>(.*)<\/title>/)
              $1
            end # user_create

            def production_create(params = {})
              parsed_response = aa.parsed_response
              links = parsed_response['links']
              link_self_index = links.index { |link| link['rel'].downcase == 'self' }
              link_self_href = links[link_self_index]['href']
              [ parsed_response['ea:productionId'], link_self_href ]
            end # production_create

            def production_list(params = {})
              production_array = [ ]
              productions = aa.parsed_response['productions']
              productions.each do |production|
                production_name = production['properties']['name']
                production_id   = production['ea:productionId']
                production_href = production['links'].first['href']
                production_array << [production_name, production_id, production_href]
              end
              production_array
            end # production_list

          end # << self

        end # ResponseHandler


        def send(method_name, method_arguments, params = {})
          method_name = method_name.to_sym
          logger.debug { "Executing Method: #{method_name}" }

          send_arguments = [ method_name ]

          if method_arguments
            method_arguments = JSON.parse(method_arguments) if method_arguments.is_a?(String) and method_arguments.start_with?('{', '[')
            send_arguments << method_arguments
          end

          response = aa.__send__(*send_arguments)

          if aa.response.code.to_i.between?(500,599)
            puts aa.parsed_response
            exit
          end

          if ResponseHandler.respond_to?(method_name)
            ResponseHandler.aa = aa
            ResponseHandler.response = response
            response = ResponseHandler.__send__(*send_arguments)
          end

          if params[:pretty_print]
            if response.is_a?(String) and response.lstrip.start_with?('{', '[')
              puts JSON.pretty_generate(JSON.parse(response))
            else
              pp response
            end
          else
            response = JSON.generate(response) if response.is_a?(Hash) or response.is_a?(Array)
            puts response
          end
          exit
        end # send

      end # CLI

    end # Utilities

  end # API

end # AdobeAnywhere
