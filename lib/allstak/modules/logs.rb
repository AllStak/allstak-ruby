module AllStak
  module Modules
    # Buffered structured-log ingestion. Each log is sent as its own POST.
    class Logs
      PATH = "/ingest/v1/logs".freeze
      VALID_LEVELS = %w[debug info warn error fatal].freeze

      def initialize(transport, config, logger)
        @transport = transport
        @config = config
        @logger = logger
        @buffer = Transport::FlushBuffer.new(
          name: "logs",
          max_size: config.buffer_size,
          interval_ms: config.flush_interval_ms,
          flush_proc: method(:flush_batch),
          logger: logger
        )
      end

      def log(level, message, service: nil, trace_id: nil, span_id: nil,
              request_id: nil, user_id: nil, error_id: nil, metadata: nil)
        return if @transport.disabled?
        level = normalize_level(level)

        payload = {
          level: level,
          message: message.to_s,
          service: service || @config.service_name,
          environment: @config.environment,
          release: @config.respond_to?(:release) ? @config.release : nil,
          traceId: trace_id,
          spanId: span_id,
          requestId: request_id,
          userId: user_id,
          errorId: error_id,
          metadata: metadata
        }.compact
        @buffer.push(payload)
      end

      def debug(msg, **kw); log("debug", msg, **kw); end
      def info(msg, **kw);  log("info",  msg, **kw); end
      def warn(msg, **kw);  log("warn",  msg, **kw); end
      def error(msg, **kw); log("error", msg, **kw); end
      def fatal(msg, **kw); log("fatal", msg, **kw); end

      def flush
        @buffer.flush
      end

      def shutdown
        @buffer.shutdown
      end

      private

      def normalize_level(level)
        lv = level.to_s.downcase
        lv = "warn" if lv == "warning"
        VALID_LEVELS.include?(lv) ? lv : "info"
      end

      def flush_batch(items)
        items.each do |item|
          begin
            @transport.post(PATH, item)
          rescue Transport::AllStakAuthError
            return
          rescue Transport::AllStakTransportError => e
            @logger.debug("[AllStak] log transport error (discarding): #{e.message}")
          rescue => e
            @logger.debug("[AllStak] unexpected log error: #{e.message}")
          end
        end
      end
    end
  end
end
