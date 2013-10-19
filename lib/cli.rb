require 'logger'
require 'optparse'
module CLI

  LOGGING_LEVELS = {
      :debug => Logger::DEBUG,
      :info => Logger::INFO,
      :warn => Logger::WARN,
      :error => Logger::ERROR,
      :fatal => Logger::FATAL
  }

  class <<self

    attr_accessor :options

  end

  class CommonOptionParser < ::OptionParser

    attr_accessor :options

    #def options=(value)
    #  #puts "Setting #{self.class.name}[#{self.object_id}] options => (#{value.class.name}[#{value.object_id}]) #{value}"
    #  @options = value
    #end
    #
    #def options
    #  #puts "Getting #{self.class.name}[#{self.object_id}] options. #{@options}"
    #  @options
    #end

    def parse_common
      #puts "Parsing #{self.class.name}[#{self.object_id}] options. #{@options}"
      parse!(ARGV.dup)

      options_file_path = options[:options_file_path]
      # Make sure that options from the command line override those from the options file
      parse!(ARGV.dup) if options_file_path and load(options_file_path)

      check_required_arguments
    end

    def required_arguments; @required_arguments ||= [ ] end
    def add_required_argument(*args)  [*args].each { |arg| required_arguments << arg } end
    alias :add_required_arguments :add_required_argument

    def missing_required_arguments
      puts "Options #{options}"
      required_arguments.dup.delete_if { |a| options.has_key?(a.is_a?(Hash) ? a.keys.first : a) }
    end

    def check_required_arguments
      _missing_arguments = missing_required_arguments
      unless _missing_arguments.empty?
        abort "Missing Required Arguments: #{_missing_arguments.map { |v| (v.is_a?(Hash) ? v.values.first : v).to_s.sub('_', '-')}.join(', ')}\n#{self.to_s}"
      end
    end
  end # CommonOptionParser

  def self.new_common_option_parser(*args)
    op = CommonOptionParser.new(*args)
    op.options = options
    op
  end

end

@options = options ||= { } #HashTap.new
def options; @options end
def common_option_parser
  @common_option_parser ||= begin
    CLI.options ||= options
    CLI.new_common_option_parser
  end
end
def add_common_options
  options[:log_level] ||= 1
  common_option_parser.on('--[no-]options-file [FILENAME]', "\tdefault: #{options[:options_file_path]}" ) { |v| options[:options_file_path] = v }
  common_option_parser.on('--log-to FILENAME', 'Log file location.', "\tdefault: STDERR") { |v| options[:log_to] = v }
  common_option_parser.on('--log-level LEVEL', CLI::LOGGING_LEVELS.keys, "Logging level. Available Options: #{CLI::LOGGING_LEVELS.keys.join(', ')}",
                          "\tdefault: #{CLI::LOGGING_LEVELS.invert[options[:log_level]]}") { |v| options[:log_level] = CLI::LOGGING_LEVELS[v] }
  common_option_parser.on('-h', '--help', 'Show this message.') { puts common_option_parser; exit }
end

default_options_file_path = File.join(File.expand_path('.'), "#{File.basename($0, '.rb')}_options")
options[:options_file_path] = default_options_file_path if File.exists?(default_options_file_path)
options[:options_file_path] ||= File.expand_path(File.basename($0, '.*'), '~/.options')
