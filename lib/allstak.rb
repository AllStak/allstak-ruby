require "logger"
require "time"

require_relative "allstak/version"
require_relative "allstak/config"
require_relative "allstak/transport/http_transport"
require_relative "allstak/transport/flush_buffer"
require_relative "allstak/models/user_context"
require_relative "allstak/modules/errors"
require_relative "allstak/modules/logs"
require_relative "allstak/modules/http_monitor"
require_relative "allstak/modules/tracing"
require_relative "allstak/modules/database"
require_relative "allstak/modules/cron"
require_relative "allstak/client"
require_relative "allstak/integrations/rack"
require_relative "allstak/integrations/active_record"
require_relative "allstak/integrations/net_http"

# Official AllStak Ruby SDK.
#
# Quick start:
#
#   require "allstak"
#
#   AllStak.configure do |c|
#     c.api_key      = ENV["ALLSTAK_API_KEY"]
#     c.environment  = "production"
#     c.release      = "myapp@1.2.3"
#     c.service_name = "myapp-api"
#   end
#
#   # Rack / Rails: add the middleware
#   use AllStak::Integrations::Rack::Middleware
#
#   # Manual:
#   AllStak.capture_exception(exc)
#   AllStak.log.info("hello", metadata: { foo: "bar" })
#   AllStak.cron.job("daily-report") { generate_report }
module AllStak
  @mutex = Mutex.new

  class << self
    attr_reader :logger

    def configure
      @mutex.synchronize do
        @config ||= Config.new
        yield @config if block_given?
        @logger = Logger.new($stderr).tap do |l|
          l.level = @config.debug ? Logger::DEBUG : Logger::WARN
          l.progname = "allstak"
        end
        if @config.valid?
          @client = Client.new(@config, @logger)
          # Auto-wire integrations that are safe to install
          AllStak::Integrations::ActiveRecordIntegration::Subscriber.install!
          AllStak::Integrations::NetHTTP.install!
        else
          @logger.warn("[AllStak] api_key not set — SDK not started")
          @client = nil
        end
        @client
      end
    end

    def initialized?
      !@client.nil?
    end

    def client
      @client or raise "AllStak not configured. Call AllStak.configure { |c| ... } first."
    end

    def capture_exception(exc, **kw)
      @client&.capture_exception(exc, **kw)
    end

    def capture_error(exception_class, message, **kw)
      @client&.capture_error(exception_class, message, **kw)
    end

    # Cross-SDK parity with JS captureMessage / Python capture_message /
    # Java captureMessage. Emits a string as an error-group entry at the
    # given level. Safe no-op if the SDK is not configured.
    def capture_message(message, level: "info", **kw)
      @client&.capture_message(message, level: level, **kw)
    end

    def set_user(**kw)
      @client&.set_user(**kw)
    end

    def clear_user
      @client&.clear_user
    end

    # Attach a tag that sticks to every future event.
    # Cross-SDK parity with JS setTag / Python set_tag.
    def set_tag(key, value)
      @client&.set_tag(key, value)
    end

    def set_tags(pairs)
      @client&.set_tags(pairs)
    end

    # Attach a custom context entry to every future event.
    # Cross-SDK parity with JS/Python setContext.
    def set_context(key, value)
      @client&.set_context(key, value)
    end

    def log
      @client&.logs
    end

    def tracing
      @client&.tracing
    end

    def http
      @client&.http
    end

    def database
      @client&.database
    end

    def cron
      @client&.cron
    end

    def flush
      @client&.flush
    end

    def shutdown
      @client&.shutdown
    end

    # Test helper.
    def reset!
      @mutex.synchronize do
        @client&.shutdown rescue nil
        @client = nil
        @config = nil
      end
    end
  end
end
