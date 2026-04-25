require "json"

module AllStak
  module Modules
    # Captures exceptions and sends them to AllStak.
    class Errors
      PATH = "/ingest/v1/errors".freeze
      MAX_BREADCRUMBS = 50

      def initialize(transport, config, logger)
        @transport = transport
        @config = config
        @logger = logger
        @current_user = nil
        @breadcrumbs = []
        @breadcrumb_mutex = Mutex.new
      end

      def set_user(id: nil, email: nil, ip: nil)
        @current_user = Models::UserContext.new(id: id, email: email, ip: ip)
      end

      def clear_user
        @current_user = nil
      end

      def add_breadcrumb(type:, message:, level: "info", data: nil)
        @breadcrumb_mutex.synchronize do
          @breadcrumbs.shift if @breadcrumbs.length >= MAX_BREADCRUMBS
          @breadcrumbs << {
            timestamp: Time.now.utc.iso8601(6),
            type: type,
            message: message,
            level: level,
            data: data
          }.compact
        end
      end

      def capture_exception(exc, level: "error", user: nil, request_context: nil, trace_id: nil, metadata: nil)
        return nil if @transport.disabled?
        begin
          crumbs = @breadcrumb_mutex.synchronize do
            next nil if @breadcrumbs.empty?
            out = @breadcrumbs.dup
            @breadcrumbs.clear
            out
          end

          payload = {
            exceptionClass: exc.class.name,
            message: exc.message.to_s.empty? ? exc.class.name : exc.message.to_s,
            stackTrace: extract_frames(exc),
            level: level,
            environment: @config.environment,
            release: @config.release,
            # Phase 3 — v2 ingest contract: top-level identity + frames.
            sdkName:    @config.sdk_name,
            sdkVersion: @config.sdk_version,
            platform:   @config.platform,
            dist:       @config.dist,
            frames:     extract_structured_frames(exc),
            traceId: trace_id,
            user: (user || @current_user)&.to_h,
            requestContext: request_context&.to_h,
            metadata: @config.release_tags.merge(metadata || {}),
            breadcrumbs: crumbs
          }.compact
          payload.delete(:user)           if payload[:user]&.empty?
          payload.delete(:requestContext) if payload[:requestContext]&.empty?

          status, body = @transport.post(PATH, payload)
          return nil unless status == 202
          parsed = JSON.parse(body) rescue nil
          parsed&.dig("data", "id")
        rescue Transport::AllStakAuthError
          nil
        rescue => e
          @logger.debug("[AllStak] capture_exception swallowed: #{e.class}: #{e.message}")
          nil
        end
      end

      def capture_error(exception_class, message, stack_trace: nil, level: "error", user: nil, request_context: nil, trace_id: nil, metadata: nil)
        return nil if @transport.disabled?
        begin
          payload = {
            exceptionClass: exception_class,
            message: message,
            stackTrace: stack_trace,
            level: level,
            environment: @config.environment,
            release: @config.release,
            traceId: trace_id,
            user: (user || @current_user)&.to_h,
            requestContext: request_context&.to_h,
            metadata: @config.release_tags.merge(metadata || {})
          }.compact
          payload.delete(:user)           if payload[:user]&.empty?
          payload.delete(:requestContext) if payload[:requestContext]&.empty?
          status, _ = @transport.post(PATH, payload)
          status == 202 ? exception_class : nil
        rescue => e
          @logger.debug("[AllStak] capture_error swallowed: #{e.class}: #{e.message}")
          nil
        end
      end

      private

      def extract_frames(exc)
        return [] unless exc.backtrace.is_a?(Array)
        exc.backtrace.first(50)
      end

      # Phase 3 — v2 structured frames. Ruby's backtrace is "<file>:<line>:in `<fn>'"
      # — split it into the wire shape so the dashboard can render real
      # source paths. Falls back to nil when no backtrace is present.
      def extract_structured_frames(exc)
        return nil unless exc.backtrace.is_a?(Array)
        out = []
        exc.backtrace.first(50).each do |line|
          if line =~ /^(.*):(\d+):in [`'](.+?)'/
            out << {
              filename: $1, absPath: $1,
              function: $3, lineno: Integer($2),
              inApp: !$1.include?('/gems/') && !$1.start_with?('<internal:'),
              platform: 'ruby'
            }
          end
        end
        out.empty? ? nil : out
      end
    end
  end
end
