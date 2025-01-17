class TD::UpdateManager
  TIMEOUT = 30

  def initialize
    @handlers = Concurrent::Array.new
    @mutex = Mutex.new
  end

  def add_handler(handler)
    @mutex.synchronize { @handlers << handler }
  end

  alias << add_handler

  def run
    #@thread_pool.post do
    #       puts 'post'
    Thread.start do
      loop { handle_update; sleep 0.001 }
      @mutex.synchronize { @handlers = [] }
    end
  end

  private

  attr_reader :handlers

  def handle_update
    update = TD::Api.client_receive(TIMEOUT)

    unless update.nil?
      extra  = update.delete('@extra')
      update = TD::Types.wrap(update)

      match_handlers!(update, extra).each { |h| h.async.run(update) }
    end
  rescue StandardError => e
    warn("Uncaught exception in update manager: #{e.message}")
  end

  def match_handlers!(update, extra)
    @mutex.synchronize do
      matched_handlers = handlers.select { |h| h.match?(update, extra) }
      matched_handlers.each { |h| handlers.delete(h) if h.disposable? }
      matched_handlers
    end
  end
end
