module AllStak
  # SDK configuration. Populated via {AllStak.configure}.
  class Config
    attr_accessor :api_key, :host, :environment, :release, :service_name,
                  :flush_interval_ms, :buffer_size, :debug,
                  :connect_timeout, :read_timeout, :max_retries,
                  :capture_unhandled_exceptions, :capture_http_requests,
                  :capture_user_context, :capture_sql

    def initialize
      @api_key         = ENV["ALLSTAK_API_KEY"].to_s
      @host            = ENV["ALLSTAK_HOST"] || "https://api.allstak.sa"
      @environment     = ENV["ALLSTAK_ENVIRONMENT"]
      @release         = ENV["ALLSTAK_RELEASE"]
      @service_name    = ENV["ALLSTAK_SERVICE"] || "ruby-service"
      @flush_interval_ms = 2_000
      @buffer_size     = 500
      @debug           = !ENV["ALLSTAK_DEBUG"].to_s.empty?
      @connect_timeout = 3
      @read_timeout    = 3
      @max_retries     = 5
      @capture_unhandled_exceptions = true
      @capture_http_requests        = true
      @capture_user_context         = true
      @capture_sql                  = true
    end

    def valid?
      !@api_key.to_s.empty?
    end

    def host=(value)
      @host = value.to_s.sub(%r{/+\z}, "")
    end
  end
end
