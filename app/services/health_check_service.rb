# Each public method is one check: its name is the JSON key, and it returns true or false.
# `app` is always here; the others are the services DevCine depends on.
class HealthCheckService
  TIMEOUT = 5

  def call
    checks.index_with { |name| safely { public_send(name) } }
  end

  # The project answers its own /up (Rails' built-in health page).
  def app
    HTTParty.get(ENV.fetch("SERVICES_HEALTH_CHECK_APP_URL", "http://localhost:#{ENV.fetch("PORT", 3000)}/up"),
                 timeout: TIMEOUT).success?
  end

  # Rails.cache stores and returns a value. In production that's Solid Cache on its own
  # database, which swallows its errors, so a dead cache only shows up here. The key is
  # unique per call so two checks running at once can't overwrite each other.
  def cache
    key = "health_check/#{SecureRandom.uuid}"
    Rails.cache.write(key, true, expires_in: 1.minute)
    Rails.cache.read(key) == true
  ensure
    Rails.cache.delete(key)
  end

  # The primary database answers.
  def database
    ActiveRecord::Base.with_connection { |connection| connection.select_value("SELECT 1") } == 1
  end

  # ffmpeg and ffprobe run: thumbnail suggestions, MKV ingest and HLS packaging need them.
  # VideoFrameExtractor caches the answer per process.
  def ffmpeg
    VideoFrameExtractor.available?
  end

  # A Solid Queue process (inside Puma in production) has checked in recently, so ingest
  # and HLS packaging jobs get picked up. Reported only where Active Job runs on Solid
  # Queue; see `checks`.
  def queue
    SolidQueue::Process.where(last_heartbeat_at: SolidQueue.process_alive_threshold.ago..).exists?
  end

  # The Active Storage disk (the /opt/devcine_storage mount in production) is there and
  # writable: every video, subtitle and thumbnail file lives on it.
  def storage
    root = ActiveStorage::Blob.service.root
    File.directory?(root) && File.writable?(root)
  end

  private
    # `app` first, then the other checks by name. `queue` is left out where Active Job
    # doesn't run on Solid Queue (development uses the async adapter, so there's no
    # queue process to report).
    def checks
      names = self.class.public_instance_methods(false) - [ :call, :app ]
      names -= [ :queue ] unless ActiveJob::Base.queue_adapter_name == "solid_queue"
      [ :app, *names.sort ]
    end

    # A check that raises, or returns anything but true, is off. ScriptError covers checks
    # left as `raise NotImplementedError` and a `require` that fails.
    def safely
      yield == true
    rescue StandardError, ScriptError
      false
    end
end
