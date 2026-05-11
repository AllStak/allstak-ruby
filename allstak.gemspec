require_relative "lib/allstak/version"

Gem::Specification.new do |spec|
  spec.name          = "allstak"
  spec.version       = AllStak::VERSION
  spec.authors       = ["AllStak"]
  spec.email         = ["sdk@allstak.dev"]

  spec.summary       = "Official AllStak Ruby SDK — error tracking, logs, HTTP + ActiveRecord monitoring, tracing, and cron monitoring"
  spec.description   = "Production-ready Ruby SDK for AllStak observability: Rack/Rails middleware, ActiveRecord instrumentation, outbound HTTP capture, distributed tracing, cron monitoring, and structured logs."
  spec.homepage      = "https://allstak.dev"
  spec.license       = "MIT"
  spec.required_ruby_version = ">= 3.0.0"

  spec.metadata["homepage_uri"]      = spec.homepage
  spec.metadata["source_code_uri"]   = "https://github.com/AllStak/allstak-ruby"
  spec.metadata["changelog_uri"]     = "https://github.com/AllStak/allstak-ruby/blob/main/CHANGELOG.md"
  spec.metadata["bug_tracker_uri"]   = "https://github.com/AllStak/allstak-ruby/issues"
  spec.metadata["documentation_uri"] = "https://allstak.dev/docs/sdks/ruby"
  spec.metadata["rubygems_mfa_required"] = "true"

  spec.files = Dir[
    "lib/**/*.rb",
    "README.md",
    "CHANGELOG.md",
    "LICENSE",
    "allstak.gemspec"
  ]

  spec.require_paths = ["lib"]

  # No runtime dependencies — the SDK uses only the Ruby standard library.
  # Framework integrations (Rack, Rails, ActiveRecord, Net::HTTP) are loaded
  # lazily and only activate when the host app has them available.

  spec.add_development_dependency "rspec",        "~> 3.12"
  spec.add_development_dependency "webmock",      "~> 3.19"
  spec.add_development_dependency "rack",         "~> 3.0"
  spec.add_development_dependency "activerecord", "~> 8.0"
end
