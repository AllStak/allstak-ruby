module AllStak
  module Integrations
    module Rack
      # Rack middleware that:
      # 1. Starts a fresh trace per request (or adopts X-AllStak-Trace-Id / traceparent)
      # 2. Captures inbound HTTP request telemetry
      # 3. Auto-captures unhandled exceptions with full request context, user, stack, and trace link
      # 4. Re-raises so the framework's exception handler runs
      class Middleware
        def initialize(app)
          @app = app
        end

        def call(env)
          return @app.call(env) unless AllStak.initialized?

          client = AllStak.client
          config = client.config

          start = now_ms
          started_at = Time.now.utc.iso8601(3)

          # Trace id — adopt incoming or mint fresh per request
          incoming = env["HTTP_X_ALLSTAK_TRACE_ID"] || env["HTTP_TRACEPARENT"]
          if incoming && !incoming.empty?
            client.tracing.set_trace_id(incoming)
          else
            client.tracing.reset_trace
          end
          trace_id = client.tracing.current_trace_id

          status = 0
          headers = {}
          body = nil
          captured = nil

          begin
            status, headers, body = @app.call(env)
          rescue => e
            captured = e
            status = 500 if status.to_i == 0
            raise
          ensure
            duration = now_ms - start

            # Request telemetry
            if config.capture_http_requests
              begin
                req_size = env["CONTENT_LENGTH"].to_i
                resp_size = headers && headers["Content-Length"].to_i
                user_id = extract_user_id(env)
                path = env["PATH_INFO"] || "/"

                client.http.record(
                  direction: "inbound",
                  method: env["REQUEST_METHOD"] || "GET",
                  host: env["HTTP_HOST"] || "localhost",
                  path: path,
                  status_code: status.to_i,
                  duration_ms: duration,
                  request_size: req_size,
                  response_size: resp_size || 0,
                  trace_id: trace_id,
                  user_id: user_id
                )
              rescue => err
                # never raise into host
                config.debug && warn("[AllStak] rack request capture failed: #{err.message}")
              end
            end

            # Exception capture
            if captured && config.capture_unhandled_exceptions
              begin
                user_ctx = config.capture_user_context ? build_user_context(env) : nil
                req_ctx = AllStak::Models::RequestContext.new(
                  method: env["REQUEST_METHOD"],
                  path: env["PATH_INFO"],
                  host: env["HTTP_HOST"],
                  status_code: status.to_i == 0 ? 500 : status.to_i,
                  user_agent: env["HTTP_USER_AGENT"]
                )
                meta = {
                  "http.method" => env["REQUEST_METHOD"],
                  "http.path"   => env["PATH_INFO"],
                  "http.host"   => env["HTTP_HOST"],
                  "http.status" => status.to_i == 0 ? 500 : status.to_i,
                  "traceId"     => trace_id
                }
                client.errors.capture_exception(
                  captured,
                  user: user_ctx,
                  request_context: req_ctx,
                  trace_id: trace_id,
                  metadata: meta
                )
              rescue => err
                config.debug && warn("[AllStak] rack exception capture failed: #{err.message}")
              end
            end

            # Best-effort response header for downstream trace linkage
            headers["X-AllStak-Trace-Id"] = trace_id if headers && !captured
          end

          [status, headers, body]
        end

        private

        def now_ms
          (Process.clock_gettime(Process::CLOCK_MONOTONIC) * 1000).to_i
        end

        def extract_user_id(env)
          # Rack-standard: env["warden"]? env["rack.session"]?
          # Apps can set env["allstak.user_id"] directly.
          return env["allstak.user_id"].to_s if env["allstak.user_id"]
          if (session = env["rack.session"])
            id = session["user_id"] || session[:user_id]
            return id.to_s if id
          end
          nil
        end

        def build_user_context(env)
          id = extract_user_id(env)
          email = env["allstak.user_email"]
          return nil if id.nil? && email.nil?
          ip = env["REMOTE_ADDR"] || env["HTTP_X_FORWARDED_FOR"]
          AllStak::Models::UserContext.new(id: id, email: email, ip: ip)
        end
      end
    end
  end
end
