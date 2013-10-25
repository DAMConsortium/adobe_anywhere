require 'optparse'

require 'adobe_anywhere'
module AdobeAnywhere

  class CLI

    attr_accessor :logger

    LOGGING_LEVELS = {
      :debug => Logger::DEBUG,
      :info => Logger::INFO,
      :warn => Logger::WARN,
      :error => Logger::ERROR,
      :fatal => Logger::FATAL
    }


  end # CLI

end # AdobeAnywhere