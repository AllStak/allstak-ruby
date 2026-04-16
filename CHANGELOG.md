# Changelog

All notable changes to the AllStak Ruby SDK.
This project follows [Semantic Versioning](https://semver.org/).

## 0.1.0 — 2026-04-11

First public release. Driven end-to-end through a real Sinatra + ActiveRecord
+ SQLite + JWT application (TaskFlow API) with full auth, CRUD, validation,
outbound HTTP, cron, and real exceptions — verified in the AllStak dashboard
against every feature page via Chrome DevTools MCP.

### Highlights

- **Rack middleware** that auto-captures inbound HTTP telemetry, unhandled
  exceptions, request context, user context (env-standard + session), and
  per-request trace lifecycle in one line: `use AllStak::Integrations::Rack::Middleware`.
- **ActiveRecord instrumentation** via `ActiveSupport::Notifications`
  (`sql.active_record` subscriber) — zero-config, one event per query,
  no duplication.
- **Net::HTTP instrumentation** via `Module#prepend` on `Net::HTTP#request` —
  all convenience methods (`get`, `post`, etc.) funnel through `#request`, so
  there is no duplication, and calls to the AllStak ingest host are filtered
  out to avoid recursive instrumentation.
- **Distributed tracing** with `AllStak.tracing.in_span(...)` block form that
  uses `ensure` to finish the span even on non-local flow (`throw :halt`,
  early returns, etc.) — so Sinatra's `halt` does not orphan spans.

### Added

- `AllStak::Config` — all config via ENV or block form, with sensible defaults.
- `AllStak::Transport::HttpTransport` — retry/backoff (1s → 2s → 4s → 8s
  + jitter, max 5), 401 disable, 4xx no-retry, thread-safe.
- `AllStak::Transport::FlushBuffer` — bounded ring buffer with background
  timer thread, 80% early-flush, overflow warning, single-flight drain.
- `AllStak::Modules::Errors` — `capture_exception`, `capture_error`,
  breadcrumbs, user context, full `RequestContext` + trace ID serialization.
- `AllStak::Modules::Logs` — buffered structured logs with
  `debug | info | warn | error | fatal` levels (normalizes `"warning"` → `"warn"`).
- `AllStak::Modules::HttpMonitor` — inbound + outbound HTTP telemetry,
  batched up to 100 per POST, query-string stripping.
- `AllStak::Modules::Tracing` — span hierarchy with thread-local parent
  tracking, `finish`-on-`ensure` block helper.
- `AllStak::Modules::Database` — normalized SQL, MD5 query hash, query-type
  detection, status + error + row count, batched up to 100.
- `AllStak::Modules::Cron` — `job(slug) { ... }` block helper with success
  and failure heartbeat, plus direct `ping`.
- `AllStak::Integrations::Rack::Middleware` — Rack 3-compatible middleware
  with trace adoption (`X-AllStak-Trace-Id` / `traceparent`).
- `AllStak::Integrations::ActiveRecordIntegration::Subscriber` —
  `sql.active_record` subscriber, auto-installed by `AllStak.configure`.
- `AllStak::Integrations::NetHTTP` — `Net::HTTP#request` patch,
  auto-installed by `AllStak.configure`.
- `AllStak::Models::UserContext` / `RequestContext` — serialized objects
  attached to error events.

### Verified production surface

- Real register/login/logout/JWT flow ✔
- Real CRUD with ownership / forbidden / 404 / state-transition guards ✔
- Real ActiveRecord validation failures ✔
- Real unhandled exceptions with full stack, user, request context, trace ✔
- 89 logs across `taskflow-ruby-api` service ✔
- 97 inbound + 3 outbound HTTP requests (success + failure) ✔
- 349 ActiveRecord queries (SELECT / INSERT / UPDATE / DELETE) grouped ✔
- Distributed tracing with span linking on error detail ✔
- 2 cron monitors (healthy + failed) auto-created ✔

### Breaking changes

None — initial public release.
