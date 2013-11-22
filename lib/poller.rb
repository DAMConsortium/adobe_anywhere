require 'eventmachine'
require 'logger'

class Poller

  class BasicWorker
    def self.run; warn 'POLL METHOD HAS NOT BEEN IMPLEMENTED' end
  end # Basic Worker

  DEFAULT_POLL_INTERVAL = 60

  attr_accessor :interrupted, :sleeping, :worker

  attr_writer :logger, :poll_interval

  class << self

    def poll(*args); poller = new(*args); poller.poll; poller end # poll
    def start(*args); poller = new(*args); poller.start; poller end # start

  end # self

  # @param [Hash] params ({ })
  # @option params [Object] :logger (Logger)
  # @option params [String] :log_to (STDOUT)
  # @option params [Integer] :poll_interval (DEFAULT_POLL_INTERVAL)
  # @option params [#run] :worker (BasicWorker)
  def initialize(params = { })
    @logger = params[:logger] || Logger.new(params[:log_to] || STDOUT)
    @poll_interval = params[:poll_interval] || DEFAULT_POLL_INTERVAL

    @worker = params[:worker] || BasicWorker
    raise ArgumentError, "Worker must have a 'run' method." unless @worker.respond_to?(:run)
  end #

  def poll_interval; @poll_interval ||= DEFAULT_POLL_INTERVAL end # poll_interval
  def logger; @logger ||= Logger.new(STDOUT) end # logger

  def run
    poll
    _sleep
  end # run

  def start(*args)
    EventMachine.run do
      Signal.trap 'INT', stop_proc
      Signal.trap 'TERM', stop_proc
      Signal.trap 'SIGINT', stop_proc
      run until interrupted
    end # EventMachine.run
  end # start(*args)

  def stop_proc
    @stop_proc ||= Proc.new do
      logger.info { 'Stopping.' }
      @interrupted = true
      EventMachine.stop
      raise Interrupt if sleeping
    end
  end

  def stop; stop_proc.call end # stop

  # @param [Integer, Float] interval
  def _sleep(interval = poll_interval)
    return if interrupted
    logger.info { "Sleeping for #{interval} seconds." }
    begin
      @sleeping = true
      sleep(interval)
      @sleeping = false
    rescue SystemExit, Interrupt
      #logger.debug { 'Sleep Interrupted.' }
    end
  end

  def poll(*args)
    # raise NotImplementedError.new('The poll method has not been implemented.')
    @worker.run
  end # poll

end # Poller