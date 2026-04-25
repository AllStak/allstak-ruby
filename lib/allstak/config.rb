module AllStak
  # SDK configuration. Populated via {AllStak.configure}.
  class Config
    SDK_NAME    = "allstak-ruby"
    SDK_VERSION = "1.2.0"

    attr_accessor :api_key, :host, :environment, :release, :service_name,
                  :flush_interval_ms, :buffer_size, :debug,
                  :connect_timeout, :read_timeout, :max_retries,
                  :capture_unhandled_exceptions, :capture_http_requests,
                  :capture_user_context, :capture_sql,
                  # Release-tracking metadata. All optional; we auto-detect
                  # the common ones from CI env vars below.
                  :dist, :commit_sha, :branch, :platform, :sdk_name, :sdk_version

    def initialize
      @api_key         = ENV["ALLSTAK_API_KEY"].to_s
      @host            = ENV["ALLSTAK_HOST"] || "https://api.allstak.sa"
      @environment     = ENV["ALLSTAK_ENVIRONMENT"] || ENV["RAILS_ENV"] || ENV["RACK_ENV"] || "production"
      @release         = ENV["ALLSTAK_RELEASE"] ||
                         ENV["VERCEL_GIT_COMMIT_SHA"]&.slice(0, 12) ||
                         ENV["RAILWAY_GIT_COMMIT_SHA"]&.slice(0, 12) ||
                         ENV["RENDER_GIT_COMMIT"]&.slice(0, 12)
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
      # Release metadata
      @platform    = "ruby"
      @sdk_name    = SDK_NAME
      @sdk_version = SDK_VERSION
      @commit_sha  = ENV["ALLSTAK_COMMIT_SHA"] || ENV["GIT_COMMIT"] || ENV["VERCEL_GIT_COMMIT_SHA"] ||
                     ENV["RAILWAY_GIT_COMMIT_SHA"] || ENV["RENDER_GIT_COMMIT"]
      @branch      = ENV["ALLSTAK_BRANCH"] || ENV["GIT_BRANCH"] || ENV["VERCEL_GIT_COMMIT_REF"] ||
                     ENV["RAILWAY_GIT_BRANCH"]
    end

    # Release-tracking tags merged into every event payload's metadata.
    def release_tags
      tags = {}
      tags["sdk.name"]     = @sdk_name     if @sdk_name
      tags["sdk.version"]  = @sdk_version  if @sdk_version
      tags["platform"]     = @platform     if @platform
      tags["dist"]         = @dist         if @dist
      tags["commit.sha"]   = @commit_sha   if @commit_sha
      tags["commit.branch"] = @branch      if @branch
      tags
    end

    def valid?
      !@api_key.to_s.empty?
    end

    def host=(value)
      @host = value.to_s.sub(%r{/+\z}, "")
    end
  end
end
