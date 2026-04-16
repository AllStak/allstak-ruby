module AllStak
  module Integrations
    module ActiveRecordIntegration
      # Subscribes to `sql.active_record` via ActiveSupport::Notifications and records
      # every ORM-level query with timing, status, and connection metadata.
      #
      # Skips:
      #   * schema / EXPLAIN / SAVEPOINT / TRANSACTION / nil SQL
      #   * our own AllStak internal transport (there is none on AR side, but guarded)
      #
      # Duplicates are avoided because ActiveRecord fires a single `sql.active_record`
      # event per executed command — whether it's from an ORM query, a `find_by_sql`,
      # or `connection.execute`. Raw-SQL executions done through the AR connection
      # are therefore captured via the same subscriber without double-counting.
      class Subscriber
        IGNORED_NAMES = [
          "SCHEMA", "EXPLAIN", "TRANSACTION", "SAVEPOINT", "RELEASE SAVEPOINT"
        ].freeze

        def self.install!
          return if @installed
          return unless defined?(::ActiveSupport::Notifications)

          ::ActiveSupport::Notifications.subscribe("sql.active_record") do |*args|
            begin
              event = ::ActiveSupport::Notifications::Event.new(*args)
              name = event.payload[:name].to_s
              sql  = event.payload[:sql].to_s
              next if sql.empty?
              next if IGNORED_NAMES.include?(name)
              next unless AllStak.initialized?

              client = AllStak.client
              config = client.config
              next unless config.capture_sql

              status = event.payload[:exception] ? "error" : "success"
              error_message = event.payload[:exception].is_a?(Array) ? event.payload[:exception].last.to_s : nil
              rows = event.payload[:row_count].to_i rescue -1

              db_name = nil
              db_type = nil
              if defined?(::ActiveRecord::Base) && ::ActiveRecord::Base.respond_to?(:connection_db_config)
                begin
                  cfg = ::ActiveRecord::Base.connection_db_config
                  db_name = cfg.database rescue nil
                  db_type = cfg.adapter  rescue nil
                rescue
                end
              end

              client.database.record(
                sql: sql,
                duration_ms: event.duration.to_i,
                status: status,
                error_message: error_message,
                database_name: db_name,
                database_type: db_type,
                rows_affected: rows >= 0 ? rows : -1,
                trace_id: client.tracing.current_trace_id,
                span_id: client.tracing.current_span_id
              )
            rescue => e
              # never raise into host
              AllStak.logger.debug("[AllStak] AR subscriber error: #{e.message}") rescue nil
            end
          end

          @installed = true
        end

        def self.installed?
          @installed == true
        end
      end
    end
  end
end
