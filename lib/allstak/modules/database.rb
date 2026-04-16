require "digest"

module AllStak
  module Modules
    # Database query telemetry, batched up to 100 per POST.
    class Database
      PATH = "/ingest/v1/db".freeze
      BATCH_SIZE = 100

      def initialize(transport, config, logger)
        @transport = transport
        @config = config
        @logger = logger
        @buffer = Transport::FlushBuffer.new(
          name: "database",
          max_size: config.buffer_size,
          interval_ms: config.flush_interval_ms,
          flush_proc: method(:flush_batch),
          logger: logger
        )
      end

      def record(sql:, duration_ms:, status: "success", error_message: nil,
                 database_name: nil, database_type: nil, query_type: nil,
                 rows_affected: -1, trace_id: nil, span_id: nil)
        return if @transport.disabled?
        normalized = self.class.normalize_query(sql)
        @buffer.push({
          normalizedQuery: normalized,
          queryHash: self.class.hash_query(normalized),
          queryType: query_type || self.class.detect_query_type(normalized),
          durationMs: [duration_ms.to_i, 0].max,
          timestampMillis: (Time.now.to_f * 1000).to_i,
          status: status,
          errorMessage: error_message && error_message.to_s[0, 500],
          databaseName: database_name,
          databaseType: database_type,
          service: @config.service_name,
          environment: @config.environment,
          traceId: trace_id,
          spanId: span_id,
          rowsAffected: rows_affected
        }.compact)
      end

      def flush
        @buffer.flush
      end

      def shutdown
        @buffer.shutdown
      end

      def self.normalize_query(sql)
        s = sql.to_s.dup
        s.gsub!(/'[^']*'/, "?")
        s.gsub!(/\b\d+(\.\d+)?\b/, "?")
        s.gsub!(/\s+/, " ")
        s.strip
      end

      def self.hash_query(normalized)
        Digest::MD5.hexdigest(normalized)[0, 16]
      end

      def self.detect_query_type(sql)
        first = sql.to_s.strip.split(/\s+/, 2).first.to_s.upcase
        %w[SELECT INSERT UPDATE DELETE].include?(first) ? first : "OTHER"
      end

      private

      def flush_batch(items)
        items.each_slice(BATCH_SIZE) do |chunk|
          begin
            @transport.post(PATH, { queries: chunk })
          rescue Transport::AllStakAuthError
            return
          rescue Transport::AllStakTransportError => e
            @logger.debug("[AllStak] db batch transport error: #{e.message}")
          rescue => e
            @logger.debug("[AllStak] db batch unexpected error: #{e.message}")
          end
        end
      end
    end
  end
end
