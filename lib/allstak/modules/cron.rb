module AllStak
  module Modules
    # Cron / background-job monitoring. Backend auto-creates monitors on first ping.
    class Cron
      PATH = "/ingest/v1/heartbeat".freeze

      def initialize(transport, logger, config = nil)
        @transport = transport
        @logger = logger
        @config = config
      end

      # Wrap a job in a block; heartbeat sent on exit.
      # On success → status "success". On raise → status "failed" with message,
      # then the exception is re-raised.
      #
      # @example
      #   AllStak.cron.job("daily-report") { generate_report }
      def job(slug)
        start = (Time.now.to_f * 1000).to_i
        begin
          result = yield
          duration = (Time.now.to_f * 1000).to_i - start
          ping(slug, "success", duration)
          result
        rescue => e
          duration = (Time.now.to_f * 1000).to_i - start
          ping(slug, "failed", duration, message: e.message)
          raise
        end
      end

      def ping(slug, status, duration_ms, message: nil)
        return false if @transport.disabled?
        begin
          payload = { slug: slug, status: status, durationMs: duration_ms }
          payload[:message] = message if message
          if @config
            payload[:environment] = @config.environment if @config.respond_to?(:environment) && @config.environment
            payload[:release] = @config.release if @config.respond_to?(:release) && @config.release
          end
          code, _ = @transport.post(PATH, payload)
          code == 202
        rescue Transport::AllStakAuthError
          @logger.debug("[AllStak] cron ping skipped — SDK disabled")
          false
        rescue => e
          @logger.debug("[AllStak] cron ping failed silently: #{e.message}")
          false
        end
      end
    end
  end
end
