require "securerandom"

module AllStak
  module Modules
    # Distributed tracing — spans with parent-child hierarchy via Thread-local state.
    class Tracing
      PATH = "/ingest/v1/spans".freeze
      VALID_STATUSES = %w[ok error timeout].freeze

      def initialize(transport, config, logger)
        @transport = transport
        @config = config
        @logger = logger
        @buffer = Transport::FlushBuffer.new(
          name: "tracing",
          max_size: config.buffer_size,
          interval_ms: config.flush_interval_ms,
          flush_proc: method(:flush_batch),
          logger: logger
        )
      end

      def current_trace_id
        Thread.current[:allstak_trace_id] ||= SecureRandom.hex(16)
      end

      def set_trace_id(trace_id)
        Thread.current[:allstak_trace_id] = trace_id
      end

      def current_span_id
        stack = Thread.current[:allstak_span_stack]
        stack&.last
      end

      def reset_trace
        Thread.current[:allstak_trace_id] = nil
        Thread.current[:allstak_span_stack] = nil
      end

      def start_span(operation, description: "", tags: nil)
        trace_id = current_trace_id
        span_id = SecureRandom.hex(8)
        parent = current_span_id || ""
        Thread.current[:allstak_span_stack] ||= []
        Thread.current[:allstak_span_stack] << span_id

        Span.new(
          trace_id: trace_id,
          span_id: span_id,
          parent_span_id: parent,
          operation: operation,
          description: description,
          service: @config.service_name,
          environment: @config.environment || "",
          release: (@config.respond_to?(:release) ? @config.release : nil) || "",
          tags: tags || {},
          start_time_millis: (Time.now.to_f * 1000).to_i,
          on_finish: method(:on_span_finish)
        )
      end

      # Block-form helper: automatically finishes the span on return,
      # on raise, or on non-local flow (e.g. Sinatra's `throw :halt`).
      def in_span(operation, description: "", tags: nil)
        span = start_span(operation, description: description, tags: tags)
        status = "ok"
        begin
          return yield(span)
        rescue => e
          status = "error"
          raise
        ensure
          span.finish(status) unless span.finished?
        end
      end

      def flush
        @buffer.flush
      end

      def shutdown
        @buffer.shutdown
      end

      private

      def on_span_finish(span)
        stack = Thread.current[:allstak_span_stack]
        stack&.delete(span.span_id)
        @buffer.push(span.to_h)
      end

      def flush_batch(items)
        begin
          @transport.post(PATH, { spans: items })
        rescue Transport::AllStakAuthError
          return
        rescue Transport::AllStakTransportError => e
          @logger.debug("[AllStak] span transport error: #{e.message}")
        rescue => e
          @logger.debug("[AllStak] span unexpected error: #{e.message}")
        end
      end
    end

    class Span
      attr_reader :trace_id, :span_id

      def initialize(trace_id:, span_id:, parent_span_id:, operation:, description:,
                     service:, environment:, tags:, start_time_millis:, on_finish:, release: "")
        @trace_id = trace_id
        @span_id = span_id
        @parent_span_id = parent_span_id
        @operation = operation
        @description = description
        @service = service
        @environment = environment
        @release = release
        @tags = tags.dup
        @start_time_millis = start_time_millis
        @end_time_millis = nil
        @status = "ok"
        @finished = false
        @on_finish = on_finish
      end

      def set_tag(key, value)
        @tags[key.to_s] = value.to_s
        self
      end

      def set_description(description)
        @description = description
        self
      end

      def finished?
        @finished
      end

      def finish(status = "ok")
        return if @finished
        @finished = true
        @status = Tracing::VALID_STATUSES.include?(status) ? status : "ok"
        @end_time_millis = (Time.now.to_f * 1000).to_i
        @on_finish.call(self)
      end

      def to_h
        end_ms = @end_time_millis || (Time.now.to_f * 1000).to_i
        {
          traceId: @trace_id,
          spanId: @span_id,
          parentSpanId: @parent_span_id,
          operation: @operation,
          description: @description,
          status: @status,
          durationMs: end_ms - @start_time_millis,
          startTimeMillis: @start_time_millis,
          endTimeMillis: end_ms,
          service: @service,
          environment: @environment,
          release: @release,
          tags: @tags
        }
      end
    end
  end
end
