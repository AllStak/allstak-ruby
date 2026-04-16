require "monitor"

module AllStak
  module Transport
    # Bounded ring buffer with a background flush thread.
    #
    # * Max size: `maxsize` (default 500)
    # * Eviction: oldest item dropped when full
    # * Flush triggers: interval timer, >= 80% capacity, explicit flush, shutdown
    # * Single-flight: only one flush runs at a time
    class FlushBuffer
      include MonitorMixin

      def initialize(name:, max_size:, interval_ms:, flush_proc:, logger:)
        super()
        @name = name
        @max_size = max_size
        @interval = interval_ms / 1000.0
        @flush_proc = flush_proc
        @logger = logger
        @queue = []
        @stopped = false
        @overflow_warned = false
        @flushing_mutex = Mutex.new
        start_timer
      end

      def push(item)
        synchronize do
          if @queue.length >= @max_size
            @queue.shift
            unless @overflow_warned
              @overflow_warned = true
              @logger.warn("[AllStak] Buffer #{@name} full (#{@max_size}); oldest events dropped")
            end
          else
            @overflow_warned = false
          end
          @queue << item
        end
        flush if count >= (@max_size * 0.8)
      end

      def count
        synchronize { @queue.length }
      end

      def flush
        @flushing_mutex.synchronize do
          drained = synchronize do
            next [] if @queue.empty?
            current = @queue
            @queue = []
            current
          end
          return if drained.empty?
          begin
            @flush_proc.call(drained)
          rescue => e
            @logger.debug("[AllStak] flush error in #{@name}: #{e.class}: #{e.message}")
          end
        end
      end

      def shutdown
        @stopped = true
        @timer_thread&.wakeup rescue nil
        @timer_thread&.join(2)
        flush
      end

      private

      def start_timer
        @timer_thread = Thread.new do
          Thread.current.name = "allstak-flush-#{@name}" if Thread.current.respond_to?(:name=)
          until @stopped
            sleep @interval
            break if @stopped
            begin
              flush
            rescue => e
              @logger.debug("[AllStak] timer flush error: #{e.message}")
            end
          end
        end
        @timer_thread.abort_on_exception = false
      end
    end
  end
end
