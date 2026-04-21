# AllStak Ruby SDK

Official Ruby SDK for [AllStak](https://allstak.dev) — error tracking,
structured logs, HTTP + ActiveRecord monitoring, distributed tracing, and cron
monitoring for Rack-based Ruby applications (Rails, Sinatra, Roda, Hanami).

```ruby
gem "allstak"
```

```bash
bundle install
# or
gem install allstak
```

## 60-second setup

```ruby
require "allstak"

AllStak.configure do |c|
  c.api_key      = ENV["ALLSTAK_API_KEY"]
  c.environment  = "production"
  c.release      = "myapp@1.2.3"
  c.service_name = "myapp-api"
end

# Rack / Sinatra / Rails:
use AllStak::Integrations::Rack::Middleware

# Manual capture:
begin
  risky!
rescue => e
  AllStak.capture_exception(e)
end
```

That is the whole setup. Every request, every unhandled exception, every
ActiveRecord query, every outbound Net::HTTP call, and every trace are
captured automatically.

## Public API (cross-SDK consistent)

Every method below is a module-level method on `AllStak`, matching the
names used by the JS, Python, Java, Go, PHP, and .NET SDKs so docs carry
across languages.

```ruby
AllStak.configure { |c| ... }                          # once at bootstrap

AllStak.set_user(id: "42", email: "alice@example.com") # user context
AllStak.clear_user

AllStak.set_tag("service", "checkout")                 # sticky tag
AllStak.set_tags(region: "us-east-1", tier: "web")     # bulk
AllStak.set_context("deployment", "canary")            # sticky context

AllStak.capture_exception(exc)                         # preferred for errors
AllStak.capture_error("DomainError", "bad input")      # without a throwable
AllStak.capture_message("hello", level: "info")        # plain string event

AllStak.log.info("request started", metadata: {...})   # structured logs
AllStak.tracing                                        # Tracing module
AllStak.http                                           # HTTP monitor
AllStak.database                                       # DB query monitor
AllStak.cron.job("daily-report") { run_job }           # cron heartbeats

AllStak.flush                                          # drain buffers
AllStak.shutdown                                       # drain + close
```

`AllStak.capture_message`, `AllStak.set_tag`, and `AllStak.set_context`
landed in 0.1.1 as cross-SDK parity additions. Older 0.1.0 code that only
used `capture_exception` / `capture_error` keeps working — no breaking
changes.

## Rails

```ruby
# config/initializers/allstak.rb
require "allstak"

AllStak.configure do |c|
  c.api_key      = ENV["ALLSTAK_API_KEY"]
  c.environment  = Rails.env
  c.release      = "myapp@#{ENV['GIT_SHA'] || 'dev'}"
  c.service_name = "myapp-api"
end

Rails.application.config.middleware.use AllStak::Integrations::Rack::Middleware
```

## Sinatra

```ruby
require "sinatra/base"
require "allstak"

AllStak.configure { |c| c.api_key = ENV["ALLSTAK_API_KEY"] }

class MyApp < Sinatra::Base
  use AllStak::Integrations::Rack::Middleware
  # ...
end
```

## What gets captured automatically

| What                                  | How                                        |
| ------------------------------------- | ------------------------------------------ |
| Unhandled exceptions                  | Rack middleware                            |
| Inbound HTTP requests                 | Rack middleware                            |
| Per-request trace ID                  | Rack middleware                            |
| User context (from env/session)       | Rack middleware                            |
| ActiveRecord SQL queries              | `sql.active_record` subscriber             |
| Outbound HTTP via `Net::HTTP`         | `Net::HTTP#request` patched                |

The ActiveRecord subscriber and Net::HTTP patch are installed automatically
by `AllStak.configure` — no extra setup needed.

## ActiveRecord

`AllStak.configure` installs an `ActiveSupport::Notifications` subscriber on
`sql.active_record`, which gives you normalized SQL, duration, row counts,
status, and error messages for every query — whether it's from an Active Record
relation, a `find_by_sql`, or a raw `connection.execute`. No duplication,
because every AR query fires exactly one `sql.active_record` event.

```ruby
# Nothing to do — this just works:
User.where(email: "alice@example.com").first
# → captured as: SELECT "users".* FROM "users" WHERE "users"."email" = ? LIMIT ?
```

## Outbound HTTP (Net::HTTP)

```ruby
# Also nothing to do:
Net::HTTP.get(URI("https://api.example.com/v1/data"))
# → captured as outbound HTTP telemetry with method, host, path, status, duration
```

The SDK patches `Net::HTTP#request` at `configure` time. Since every
convenience method (`get`, `post`, `post_form`, etc.) funnels through
`#request`, there is no duplication. Calls to your AllStak ingest host are
skipped to avoid recursive instrumentation.

## Manual capture cheat sheet

```ruby
# Errors
AllStak.capture_exception(exc, metadata: { order_id: "ORD-123" })
AllStak.capture_error("StripeTimeout", "Stripe /v1/charges timed out after 30s", level: "error")

# Logs (buffered, flushed in background)
AllStak.log.info("Order placed", metadata: { id: "ORD-1" })
AllStak.log.warn("Slow query", metadata: { ms: 4500 })
AllStak.log.error("Payment failed", metadata: { gateway: "stripe" })
# valid levels: debug | info | warn | error | fatal

# Distributed tracing (block-form)
AllStak.tracing.in_span("db.query", description: "SELECT users") do |span|
  span.set_tag("db.type", "postgresql")
  rows = User.all.to_a
end

# Cron monitoring — slug auto-created on first ping
AllStak.cron.job("daily-report") do
  generate_report
end

# User context (for events that should show who was affected)
AllStak.set_user(id: "u-1", email: "alice@example.com")
AllStak.clear_user

# Graceful flush
AllStak.flush
```

## Dashboard mapping

| Your code                                 | Dashboard page        |
| ----------------------------------------- | --------------------- |
| `AllStak.capture_exception` / middleware  | **Errors**, **Incidents** |
| `AllStak.log.*`                           | **Logs**              |
| Rack middleware (inbound)                 | **Requests**          |
| `Net::HTTP` (outbound, auto)              | **Requests** (outbound) |
| ActiveRecord queries (auto)               | **Database**          |
| `AllStak.tracing.in_span`                 | **Traces**            |
| `AllStak.cron.job` / `cron.ping`          | **Cron Jobs**         |

## Configuration

| Option                    | Default                   | Notes |
| ------------------------- | ------------------------- | ----- |
| `api_key`                 | `ENV["ALLSTAK_API_KEY"]`  | Your `ask_live_...` key. |
| `host`                    | `http://localhost:8080`   | Override with your AllStak ingest host. |
| `environment`             | `nil`                     | e.g. `"production"` |
| `release`                 | `nil`                     | e.g. `"myapp@1.2.3"` |
| `service_name`            | `"ruby-service"`          | Shown on spans and logs. |
| `flush_interval_ms`       | `2000`                    | Background flush interval. |
| `buffer_size`             | `500`                     | Max buffered items per feature. |
| `debug`                   | `false`                   | Verbose SDK logging. |
| `connect_timeout`         | `3`                       | Transport connect timeout (seconds). |
| `read_timeout`            | `3`                       | Transport read timeout (seconds). |
| `max_retries`             | `5`                       | Retry 5xx with exponential backoff. |
| `capture_unhandled_exceptions` | `true`               | Auto-capture from middleware. |
| `capture_http_requests`        | `true`               | Auto-capture inbound HTTP. |
| `capture_user_context`         | `true`               | Attach user claims to errors. |
| `capture_sql`                  | `true`               | Auto-capture AR queries. |

Environment variables: `ALLSTAK_API_KEY`, `ALLSTAK_HOST`, `ALLSTAK_ENVIRONMENT`,
`ALLSTAK_RELEASE`, `ALLSTAK_SERVICE`, `ALLSTAK_DEBUG`.

## Production notes

- **Never crashes your app.** Every integration catches its own exceptions
  and logs at debug level. The middleware re-raises so your framework's
  exception handler still runs.
- **Retries.** 5xx and network errors retry with exponential backoff
  (1s → 2s → 4s → 8s, +jitter, max 5 attempts). 4xx are not retried.
- **401 disables the SDK.** An invalid API key disables the SDK for the
  rest of the process — no further events are sent, a warning is logged
  once, and your app keeps running.
- **Flush on shutdown.** `at_exit` triggers a best-effort flush.
- **Thread-safe.** All public APIs are safe to call from any thread.
  Trace context uses Ruby's thread-local storage.
- **Non-blocking.** Telemetry is buffered and flushed on background threads.
  Your request pipeline is never blocked by SDK work.

## Troubleshooting

| Symptom                              | Fix                                              |
| ------------------------------------ | ------------------------------------------------ |
| No events in dashboard               | Check `host` and `api_key`. Set `debug = true`.  |
| 401 warning                          | Invalid API key. Create a new one in Settings.   |
| Inbound requests missing             | Make sure `use AllStak::Integrations::Rack::Middleware`. |
| DB queries missing                   | Make sure `AllStak.configure` runs BEFORE your first AR query. |
| Outbound HTTP missing                | Same — `configure` must run before the first `Net::HTTP` call. |
| Cron monitor not appearing           | Auto-created on first ping; check the slug matches. |

## Full Sinatra + ActiveRecord example

```ruby
require "sinatra/base"
require "active_record"
require "allstak"

AllStak.configure do |c|
  c.api_key      = ENV["ALLSTAK_API_KEY"]
  c.environment  = "production"
  c.release      = "taskflow@1.4.2"
  c.service_name = "taskflow-api"
end

ActiveRecord::Base.establish_connection(adapter: "sqlite3", database: "app.db")

class Task < ActiveRecord::Base; end

class TaskFlow < Sinatra::Base
  use AllStak::Integrations::Rack::Middleware

  get "/tasks" do
    Task.all.to_json
  end

  post "/tasks/:id/notify" do
    task = Task.find(params[:id])
    AllStak.tracing.in_span("http.notify", description: "POST httpbin.org/post") do |span|
      span.set_tag("task.id", task.id.to_s)
      uri = URI("https://httpbin.org/post")
      Net::HTTP.post(uri, { task_id: task.id }.to_json, "Content-Type" => "application/json")
    end
    { ok: true }.to_json
  end

  error do
    # Framework-level rescue. Sinatra handles the exception before Rack middleware
    # sees it, so forward manually:
    e = env["sinatra.error"]
    AllStak.capture_exception(e) if e
    status 500
    { error: e.class.name, message: e.message }.to_json
  end
end
```

## License

MIT
