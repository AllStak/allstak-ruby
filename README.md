# allstak

**Error tracking and logs for Ruby and Rails. Rack middleware auto-wires itself.**

[![Gem Version](https://img.shields.io/gem/v/allstak.svg)](https://rubygems.org/gems/allstak)
[![CI](https://github.com/AllStak/allstak-ruby/actions/workflows/ci.yml/badge.svg)](https://github.com/AllStak/allstak-ruby/actions)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)

Official AllStak SDK for Ruby — captures exceptions, structured logs, HTTP requests, ActiveRecord queries, and distributed traces for Rack, Rails, and plain Ruby services.

## Dashboard

View captured events live at [app.allstak.sa](https://app.allstak.sa).

![AllStak dashboard](https://app.allstak.sa/images/dashboard-preview.png)

## Features

- Exception and `Thread#report_on_exception` capture
- Rack middleware for inbound HTTP telemetry
- `Net::HTTP` instrumentation for outbound requests
- ActiveRecord subscriber for SQL query capture
- Structured logs with ring-buffered breadcrumbs
- Distributed tracing and cron heartbeats
- Tested against Ruby 3.0+

## What You Get

Once integrated, every event flows to your AllStak dashboard:

- **Errors** — stack traces, breadcrumbs, release + environment tags
- **Logs** — structured logs with search and filters
- **HTTP** — inbound (Rack) and outbound (`Net::HTTP`) timing, status codes, failed calls
- **Database** — ActiveRecord SQL query capture
- **Cron monitors** — scheduled job success/failure tracking
- **Alerts** — email and webhook notifications on regressions

## Installation

```bash
gem install allstak
```

Or add to your `Gemfile`:

```ruby
gem "allstak"
```

## Quick Start

> Create a project at [app.allstak.sa](https://app.allstak.sa) to get your API key.

```ruby
require "allstak"

AllStak.configure do |c|
  c.api_key      = ENV["ALLSTAK_API_KEY"]
  c.environment  = "production"
  c.release      = "myapp@1.0.0"
  c.service_name = "myapp-api"
end

AllStak.capture_exception(StandardError.new("test: hello from allstak-ruby"))
```

Run the file — the test error appears in your dashboard within seconds.

## Get Your API Key

1. Sign up at [app.allstak.sa](https://app.allstak.sa)
2. Create a project
3. Copy your API key from **Project Settings → API Keys**
4. Export it as `ALLSTAK_API_KEY` or pass it to `AllStak.configure { |c| c.api_key = ... }`

## Configuration

| Option | Type | Required | Default | Description |
|---|---|---|---|---|
| `api_key` | `String` | yes | `ENV["ALLSTAK_API_KEY"]` | Project API key (`ask_live_…`) |
| `host` | `String` | no | `https://api.allstak.sa` | Ingest host override |
| `environment` | `String` | no | — | Deployment env |
| `release` | `String` | no | — | Version / release tag |
| `service_name` | `String` | no | `ruby-service` | Logical service identifier |
| `flush_interval_ms` | `Integer` | no | `2000` | Background flush cadence |
| `buffer_size` | `Integer` | no | `500` | Max items per buffer |
| `capture_http_requests` | `Boolean` | no | `true` | Auto-wire Net::HTTP |
| `capture_sql` | `Boolean` | no | `true` | Auto-wire ActiveRecord |
| `debug` | `Boolean` | no | `false` | Verbose SDK logging |

Environment variables: `ALLSTAK_API_KEY`, `ALLSTAK_HOST`, `ALLSTAK_ENVIRONMENT`, `ALLSTAK_RELEASE`, `ALLSTAK_SERVICE`, `ALLSTAK_DEBUG`.

## Example Usage

Capture an exception with metadata:

```ruby
AllStak.capture_exception(e, metadata: { order_id: order.id })
```

Send a structured log:

```ruby
AllStak.log.info("User signed up", metadata: { user_id: user.id })
```

Report a cron run:

```ruby
AllStak.cron.job("daily-report") { generate_report }
```

Install Rack middleware (Rails or Sinatra):

```ruby
use AllStak::Integrations::Rack::Middleware
```

## Production Endpoint

Production endpoint: `https://api.allstak.sa`. Override via `host` for self-hosted deployments:

```ruby
AllStak.configure do |c|
  c.api_key = ENV["ALLSTAK_API_KEY"]
  c.host    = "https://allstak.mycorp.com"
end
```

## Links

- Documentation: https://docs.allstak.sa
- Dashboard: https://app.allstak.sa
- Source: https://github.com/AllStak/allstak-ruby

## License

MIT © AllStak
