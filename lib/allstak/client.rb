module AllStak
  # The AllStak SDK client. Create once via {AllStak.configure}.
  class Client
    attr_reader :config, :logger, :errors, :logs, :http, :tracing, :database, :cron

    def initialize(config, logger)
      @config = config
      @logger = logger
      @transport = Transport::HttpTransport.new(config, logger)

      @errors   = Modules::Errors.new(@transport, config, logger)
      @logs     = Modules::Logs.new(@transport, config, logger)
      @http     = Modules::HttpMonitor.new(@transport, config, logger)
      @tracing  = Modules::Tracing.new(@transport, config, logger)
      @database = Modules::Database.new(@transport, config, logger)
      @cron     = Modules::Cron.new(@transport, logger)

      at_exit { shutdown rescue nil }
    end

    def set_user(id: nil, email: nil, ip: nil)
      @errors.set_user(id: id, email: email, ip: ip)
    end

    def clear_user
      @errors.clear_user
    end

    def capture_exception(exc, **kw)
      @errors.capture_exception(exc, **kw)
    end

    def capture_error(exception_class, message, **kw)
      @errors.capture_error(exception_class, message, **kw)
    end

    def flush
      @logs.flush
      @http.flush
      @tracing.flush
      @database.flush
    end

    def shutdown
      flush
      @logs.shutdown
      @http.shutdown
      @tracing.shutdown
      @database.shutdown
    end
  end
end
