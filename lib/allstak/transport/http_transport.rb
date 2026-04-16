require "net/http"
require "uri"
require "json"

module AllStak
  module Transport
    class AllStakAuthError < StandardError; end
    class AllStakTransportError < StandardError; end

    # HTTP transport with retry/backoff and 401-disable.
    #
    # Contract:
    #   connect timeout = 3s   · read timeout = 3s
    #   backoff         = 1s → 2s → 4s → 8s (+ jitter 0-500ms)
    #   max attempts    = 5
    #   401             → disable SDK
    #   4xx (400/403/404/422) → no retry
    #   5xx / network   → retry
    class HttpTransport
      NON_RETRYABLE_STATUSES = [400, 401, 403, 404, 422].freeze
      BACKOFF_DELAYS = [1.0, 2.0, 4.0, 8.0].freeze

      attr_reader :disabled

      def initialize(config, logger)
        @config = config
        @logger = logger
        @base_url = config.host
        @api_key = config.api_key
        @disabled = false
      end

      def disabled?
        @disabled
      end

      def post(path, payload)
        raise AllStakAuthError, "SDK disabled" if @disabled

        uri = URI.parse("#{@base_url}#{path}")
        http = Net::HTTP.new(uri.host, uri.port)
        http.use_ssl = (uri.scheme == "https")
        http.open_timeout = @config.connect_timeout
        http.read_timeout = @config.read_timeout

        last_exc = nil
        last_status = 0
        max_attempts = [[@config.max_retries.to_i, 1].max, 5].min

        (1..max_attempts).each do |attempt|
          begin
            req = Net::HTTP::Post.new(uri.request_uri, {
              "Content-Type"   => "application/json",
              "X-AllStak-Key"  => @api_key,
              "User-Agent"     => "allstak-ruby/#{AllStak::VERSION}"
            })
            req.body = payload.is_a?(String) ? payload : JSON.generate(payload)
            @logger.debug("[AllStak] POST #{path} attempt=#{attempt}") if @config.debug

            resp = http.request(req)
            last_status = resp.code.to_i
            body = resp.body.to_s

            if last_status == 401
              @disabled = true
              @logger.warn("[AllStak] SDK disabled: invalid API key (401). No further events will be sent.")
              raise AllStakAuthError, "Invalid API key"
            end

            return [last_status, body] if NON_RETRYABLE_STATUSES.include?(last_status)
            return [last_status, body] if last_status < 400

            # 5xx → retry
          rescue AllStakAuthError
            raise
          rescue Net::OpenTimeout, Net::ReadTimeout, Errno::ECONNREFUSED, Errno::ECONNRESET,
                 SocketError, EOFError, IOError => e
            last_exc = e
            @logger.debug("[AllStak] transport error attempt=#{attempt}: #{e.class}: #{e.message}") if @config.debug
          rescue => e
            last_exc = e
            @logger.debug("[AllStak] unexpected transport error attempt=#{attempt}: #{e.class}: #{e.message}") if @config.debug
          end

          if attempt < max_attempts
            delay = BACKOFF_DELAYS[[attempt - 1, BACKOFF_DELAYS.length - 1].min]
            delay += rand * 0.5
            sleep(delay)
          end
        end

        raise AllStakTransportError,
              "All #{max_attempts} attempts failed for POST #{path}. last_status=#{last_status} last_error=#{last_exc&.message}"
      end
    end
  end
end
