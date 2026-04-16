require "net/http"

module AllStak
  module Integrations
    # Monkey-patches Net::HTTP#request to capture outbound HTTP calls as
    # AllStak http-request telemetry with real timing, status, and size.
    #
    # No duplication: we patch at the #request level, which every Net::HTTP
    # convenience method (get, post, post_form, etc.) funnels through.
    module NetHTTP
      def self.install!
        return if @installed
        ::Net::HTTP.prepend(Patch)
        @installed = true
      end

      def self.installed?
        @installed == true
      end

      module Patch
        def request(req, body = nil, &block)
          return super unless AllStak.initialized?

          start = Process.clock_gettime(Process::CLOCK_MONOTONIC)
          host = (req["Host"] || address).to_s
          path = begin
            req.path.to_s
          rescue
            "/"
          end
          method = req.method.to_s.upcase
          status = 0
          resp_size = 0
          req_size = req.body.to_s.bytesize rescue 0
          error_fp = nil

          client = AllStak.client
          # Short-circuit: do NOT instrument our own ingest calls
          return super if host.include?("ingest") || host_matches_allstak?(host)

          begin
            response = super
            status = response.code.to_i
            resp_size = response.body.to_s.bytesize rescue 0
            response
          rescue => e
            error_fp = e.class.name
            raise
          ensure
            begin
              duration = ((Process.clock_gettime(Process::CLOCK_MONOTONIC) - start) * 1000).to_i
              client.http.record(
                direction: "outbound",
                method: method,
                host: host,
                path: path,
                status_code: status,
                duration_ms: duration,
                request_size: req_size,
                response_size: resp_size,
                trace_id: client.tracing.current_trace_id,
                error_fingerprint: error_fp
              )
            rescue
              # never raise into host
            end
          end
        end

        private

        def host_matches_allstak?(h)
          return false unless AllStak.initialized?
          base = AllStak.client.config.host.to_s
          return false if base.empty?
          begin
            uri = URI.parse(base)
            !!(uri.host && h.include?(uri.host))
          rescue
            false
          end
        end
      end
    end
  end
end
