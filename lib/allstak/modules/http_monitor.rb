require "securerandom"

module AllStak
  module Modules
    # Buffers + batches HTTP request telemetry (inbound and outbound).
    # Max batch: 100.
    class HttpMonitor
      PATH = "/ingest/v1/http-requests".freeze
      MAX_BATCH = 100

      def initialize(transport, config, logger)
        @transport = transport
        @config = config
        @logger = logger
        @buffer = Transport::FlushBuffer.new(
          name: "http",
          max_size: config.buffer_size,
          interval_ms: config.flush_interval_ms,
          flush_proc: method(:flush_batch),
          logger: logger
        )
      end

      def record(direction:, method:, host:, path:, status_code:, duration_ms:,
                 request_size: 0, response_size: 0, trace_id: nil, user_id: nil,
                 error_fingerprint: nil, span_id: nil, parent_span_id: nil)
        return if @transport.disabled?
        item = {
          direction: direction,
          method: method.to_s.upcase,
          host: host.to_s,
          path: strip_query(path.to_s),
          statusCode: status_code.to_i,
          durationMs: [duration_ms.to_i, 0].max,
          requestSize: request_size.to_i,
          responseSize: response_size.to_i,
          timestamp: Time.now.utc.iso8601(3),
          traceId: trace_id || SecureRandom.hex(16),
          userId: user_id,
          errorFingerprint: error_fingerprint,
          spanId: span_id,
          parentSpanId: parent_span_id,
          environment: @config.environment,
          release: @config.release
        }.compact
        @buffer.push(item)
      end

      def flush
        @buffer.flush
      end

      def shutdown
        @buffer.shutdown
      end

      private

      def strip_query(path)
        idx = path.index("?")
        idx ? path[0...idx] : path
      end

      def flush_batch(items)
        items.each_slice(MAX_BATCH) do |chunk|
          begin
            @transport.post(PATH, { requests: chunk })
          rescue Transport::AllStakAuthError
            return
          rescue Transport::AllStakTransportError => e
            @logger.debug("[AllStak] http batch transport error: #{e.message}")
          rescue => e
            @logger.debug("[AllStak] http batch unexpected error: #{e.message}")
          end
        end
      end
    end
  end
end
