module AllStak
  # The AllStak SDK client. Create once via {AllStak.configure}.
  class Client
    attr_reader :config, :logger, :errors, :logs, :http, :tracing, :database, :cron, :tags, :contexts

    def initialize(config, logger)
      @config = config
      @logger = logger
      @transport = Transport::HttpTransport.new(config, logger)

      @errors   = Modules::Errors.new(@transport, config, logger)
      @logs     = Modules::Logs.new(@transport, config, logger)
      @http     = Modules::HttpMonitor.new(@transport, config, logger)
      @tracing  = Modules::Tracing.new(@transport, config, logger)
      @database = Modules::Database.new(@transport, config, logger)
      @cron     = Modules::Cron.new(@transport, logger, config)
      @tags     = {}
      @contexts = {}

      at_exit { shutdown rescue nil }
    end

    def set_user(id: nil, email: nil, ip: nil)
      @errors.set_user(id: id, email: email, ip: ip)
    end

    def clear_user
      @errors.clear_user
    end

    def capture_exception(exc, **kw)
      kw = merge_default_metadata(kw)
      @errors.capture_exception(exc, **kw)
    end

    def capture_error(exception_class, message, **kw)
      kw = merge_default_metadata(kw)
      @errors.capture_error(exception_class, message, **kw)
    end

    # Capture a standalone string as an "error group" at the given level.
    # Cross-SDK parity with JS/Python/PHP/Java `captureMessage`.
    # Implemented on top of capture_error so the dashboard surfaces it as
    # an "info"/"warning"/"error" level entry in the Errors list.
    def capture_message(message, level: "info", **kw)
      kw = merge_default_metadata(kw)
      @errors.capture_error("Message", message.to_s, level: level.to_s, **kw)
    end

    # Attach a key/value tag to every subsequent event sent by the SDK.
    # Cross-SDK parity with JS `setTag` and Python `set_tag`.
    def set_tag(key, value)
      @tags[key.to_s] = value.to_s
      self
    end

    # Bulk-set tags.
    def set_tags(pairs)
      pairs.each { |k, v| set_tag(k, v) }
      self
    end

    # Attach a key/value context entry (goes into metadata on every event).
    # Cross-SDK parity with JS/Python `setContext`.
    def set_context(key, value)
      @contexts[key.to_s] = value
      self
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

    private

    # Fold the persistent tags + contexts into any explicit metadata caller
    # passed. Caller-supplied keys win on conflict.
    def merge_default_metadata(kw)
      return kw if @tags.empty? && @contexts.empty?
      base = {}
      base.merge!(@tags) unless @tags.empty?
      base.merge!(@contexts) unless @contexts.empty?
      existing = kw[:metadata] || {}
      kw.merge(metadata: base.merge(existing))
    end
  end
end
