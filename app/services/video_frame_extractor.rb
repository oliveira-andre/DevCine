# Pulls a few candidate thumbnail frames out of an uploaded video with ffmpeg,
# so the uploader can pick one instead of supplying their own image.
#
# Everything here is best-effort: a missing, broken or slow ffmpeg must never
# stop a video from being uploaded. Failures come back as an empty frame list
# with a reason, and callers carry on without suggestions.
class VideoFrameExtractor
  FRAME_COUNT = 3
  # ffmpeg gets its own wall-clock budget. `-ss` before `-i` seeks rather than
  # decoding from the top, so a frame normally lands in well under a second;
  # this only exists so a pathological file cannot hang a web request.
  PROBE_TIMEOUT = 15
  FRAME_TIMEOUT = 20
  # Sample away from both ends: the first and last moments of a video are
  # usually black, a fade or a logo card — the worst possible thumbnails.
  USABLE_RANGE = 0.10..0.90
  # Below this there is no meaningful spread to sample from.
  MIN_DURATION = 1.0

  Result = Data.define(:frames, :error) do
    def any? = frames.any?
  end

  class << self
    def call(video, count: FRAME_COUNT, at: nil)
      new(video, count:, at:).call
    end

    # Whether ffmpeg/ffprobe can actually run here. Cached per process: a
    # missing binary will not appear mid-boot, and this is on the upload path.
    def available?
      return @available unless @available.nil?

      @available = binary_runs?("ffmpeg") && binary_runs?("ffprobe")
    end

    def reset_availability!
      @available = nil
    end

    private

      # `-version` is enough: a broken install (a missing shared library, say)
      # fails to launch at all, which is exactly what we need to detect.
      def binary_runs?(binary)
        _out, _err, status = Open3.capture3(binary, "-version")
        status.success?
      rescue Errno::ENOENT, Errno::EACCES
        false
      end
  end

  def initialize(video, count: FRAME_COUNT, at: nil)
    @video = video
    @count = count
    @at = at # explicit timestamps, for tests
  end

  # Returns a Result whose `frames` are Tempfiles holding JPEGs. The caller owns
  # them and should attach or discard them promptly.
  def call
    return failure("no video file attached") unless @video.file.attached?
    return failure("ffmpeg is unavailable") unless self.class.available?

    @video.file.open do |source|
      duration = probe_duration(source.path)
      return failure("could not read the video duration") if duration.nil?
      return failure("video is too short to sample") if duration < MIN_DURATION

      frames = timestamps(duration).filter_map { |seconds| grab_frame(source.path, seconds) }
      frames.any? ? Result.new(frames:, error: nil) : failure("no frames could be extracted")
    end
  rescue StandardError => e
    # Never let a thumbnail nicety take an upload down with it.
    Rails.logger.warn("VideoFrameExtractor failed for video #{@video.id}: #{e.class}: #{e.message}")
    failure("frame extraction failed")
  end

  private

    def failure(reason) = Result.new(frames: [], error: reason)

    def probe_duration(path)
      out, _err, status = run(
        [ "ffprobe", "-v", "error", "-show_entries", "format=duration",
          "-of", "default=noprint_wrappers=1:nokey=1", path ],
        timeout: PROBE_TIMEOUT
      )
      return nil unless status&.success?

      seconds = out.to_s.strip.to_f
      seconds.positive? ? seconds : nil
    end

    # `count` distinct moments, randomly placed but spread out: the range is cut
    # into equal slices and one point is drawn from each, so two suggestions
    # can never land on the same second of footage.
    def timestamps(duration)
      return @at if @at

      first = duration * USABLE_RANGE.begin
      span = duration * (USABLE_RANGE.end - USABLE_RANGE.begin)
      slice = span / @count

      Array.new(@count) { |i| (first + (slice * i) + (rand * slice)).round(2) }
    end

    def grab_frame(source_path, seconds)
      frame = Tempfile.new([ "frame", ".jpg" ], binmode: true)
      _out, _err, status = run(
        # -ss BEFORE -i seeks without decoding the whole file. -q:v 3 is
        # visually clean while staying small enough for a thumbnail.
        [ "ffmpeg", "-hide_banner", "-loglevel", "error", "-y",
          "-ss", seconds.to_s, "-i", source_path,
          "-frames:v", "1", "-q:v", "3", "-f", "image2", frame.path ],
        timeout: FRAME_TIMEOUT
      )

      if status&.success? && File.size?(frame.path)
        frame.rewind
        frame
      else
        frame.close!
        nil
      end
    end

    # Runs argv (never a shell string, so a filename can't inject) and kills the
    # process if it outstays its budget rather than blocking the request.
    def run(argv, timeout:)
      Open3.popen3(*argv) do |stdin, stdout, stderr, wait_thread|
        stdin.close
        out = +""
        err = +""
        readers = [ [ stdout, out ], [ stderr, err ] ].map do |io, buffer|
          Thread.new { buffer << io.read.to_s }
        end

        if wait_thread.join(timeout).nil?
          Process.kill("KILL", wait_thread.pid)
          wait_thread.join
          readers.each(&:kill)
          return [ out, err, nil ]
        end

        readers.each(&:join)
        [ out, err, wait_thread.value ]
      end
    rescue Errno::ENOENT, Errno::EACCES
      [ "", "", nil ]
    end
end
