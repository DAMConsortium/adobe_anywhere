require 'adobe_anywhere/cli'
require 'adobe_anywhere/job_monitor'
module AdobeAnywhere

  class JobMonitor

    class CLI < AdobeAnywhere::CLI

      def self.run(params = {})

        options = {
            :log_to => STDOUT,
            :log_level => Logger::DEBUG,
            :poll_interval => 60,
            :mig_executable_path => '/Library/Scripts/ubiquity/media_processing_tool/bin/mig',
        }
        default_options_file_path = File.join(File.dirname($0), "#{File.basename($0, '.rb')}_options")
        #abort("#{default_options_file_path} #{File.exists?(default_options_file_path)}")
        options[:options_file_path] = default_options_file_path if File.exists?(default_options_file_path)
        options[:options_file_path] ||= File.expand_path(File.basename($0, '.*'), '~/.options')

        options[:config_file_path] = File.expand_path("../config/default/#{File.basename($0)}.rb")

        op = OptionParser.new
        op.on('--config-file FILEPATH', 'Required. The path to the configuration file.') { |v| options[:config_file_path] = v }
        op.on('--[no-]poll-interval [POLLINTERVAL]', 'The interval in which to poll for new files in the file paths.',
              "\tdefault: #{options[:poll_interval]}") { |v| options[:poll_interval] = v.to_i }
        op.on('--adobe-anywhere-host-address HOSTADDRESS', 'The AdobeAnywhere Server Host Address.') do |v|
          options[:host_address] = v
        end
        op.on('--adobe-anywhere-host-port PORT', 'The AdobeAnywhere Server Port.') { |v| options[:port] = v }
        op.on('--adobe-anywhere-username USERNAME', 'The username to use when logging into the AdobeAnywhere Server.') do |v|
          options[:username] = v
        end
        op.on('--adobe-anywhere-password PASSWORD', 'The password to use when logging into the AdobeAnywhere Server.') do |v|
          options[:password] = v
        end
        op.on('--[no-]mig-path [FILEPATH]', 'The path to the Media Information Gatherer executable.',
              'No information will be gathered on an asset if this is not specified.') { |v| options[:mig_executable_path] = v }
        op.on('--log-to FILEPATH', 'The location to log to.', "\tdefault: STDOUT") { |v| options[:log_to] = v }

        op.on('--log-level LEVEL', LOGGING_LEVELS.keys, "Logging level. Available Options: #{LOGGING_LEVELS.keys.join(', ')}",
              "\tdefault: #{LOGGING_LEVELS.invert[options[:log_level]]}") { |v| options[:log_level] = LOGGING_LEVELS[v] }

        op.on('--[no-]options-file [FILEPATH]', 'An option file to use to set additional command line options.' ) do |v|
          options[:options_file_path] = v
        end
        op.on_tail('-h', '--help', 'Show this message.') { puts op; exit }

# Parse the command line so that we can see if we have an options file
        op.parse!(ARGV.dup)
        options_file_name = options[:options_file_path]

# Make sure that options from the command line override those from the options file
        op.parse!(ARGV.dup) if op.load(options_file_name)

        logger = Logger.new(options[:log_to] || STDOUT)
        logger.level = options[:log_level] if options[:log_level]

        options[:logger] = logger
        if options[:poll_interval]
          AdobeAnywhere::JobMonitor.start(options)
        else
          AdobeAnywhere::JobMonitor.process(options)
        end

      end # self.run

    end # CLI

  end # JobMonitor

end # AdobeAnywhere