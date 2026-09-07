require "open3"

# Packages a video into HLS (fMP4 segments) with one audio rendition per
# AudioTrack, so playback runs through ONE media element (hls.js / MSE) and
# audio switching works even on single-pipeline devices (smart TVs) — the
# two-media-element trick blacks out the video there.
#
# Layout, on the same local Disk volume as everything else:
#   storage/hls/<video_id>/master.m3u8
#   storage/hls/<video_id>/video/index.m3u8 + init.mp4 + seg_*.m4s
#   storage/hls/<video_id>/audio-<n>/…      (one per track, default first)
#
# Everything is `-c copy` (the file is already H.264+AAC after VideoIngest),
# so packaging is disk-bound, not CPU-bound. The master playlist is written by
# hand so the audio names/languages come verbatim from the AudioTrack rows.
# Best-effort like the rest of the pipeline: failure leaves the video playing
# progressively (hls_ready_at stays nil) and reports instead of raising.
class HlsPackager
  Result = Data.define(:status, :renditions, :error) do
    def ok? = error.nil?
  end

  SEGMENT_SECONDS = 6
  FFMPEG_TIMEOUT = 3600

  def self.root
    Rails.root.join("storage", "hls")
  end

  def self.dir_for(video)
    root.join(video.id.to_s)
  end

  def self.call(video)
    new(video).call
  end

  def initialize(video)
    @video = video
    @dir = self.class.dir_for(video)
  end

  def call
    return failure("no video file attached") unless @video.file.attached?
    return failure("ffmpeg is unavailable") unless VideoFrameExtractor.available?

    tracks = @video.audio_tracks.ordered.with_attached_file.to_a
    return failure("no audio tracks — run videos:ingest first") if tracks.empty?

    # Build into a scratch dir and swap in atomically-ish, so a half-written
    # package can never be served.
    staging = Pathname.new(Dir.mktmpdir("hls-staging"))
    @video.file.open do |source|
      return failure("video rendition failed") unless package_video(source.path, staging)

      tracks.each_with_index do |track, index|
        ok = package_audio(track, index, source.path, staging)
        return failure("audio rendition failed for #{track.name.inspect}") unless ok
      end

      write_master(tracks, staging, source.path)
    end

    FileUtils.rm_rf(@dir)
    FileUtils.mkdir_p(@dir.dirname)
    FileUtils.mv(staging, @dir)
    @video.update!(hls_ready_at: Time.current)

    Result.new(status: :packaged, renditions: tracks.size, error: nil)
  rescue StandardError => e
    Rails.logger.warn("HlsPackager failed for video #{@video.id}: #{e.class}: #{e.message}")
    failure("packaging failed: #{e.message}")
  ensure
    FileUtils.rm_rf(staging) if staging && File.directory?(staging)
  end

  # Wipe a video's package (destroy, or a replaced/re-encoded file making it
  # stale). Clearing hls_ready_at flips playback back to progressive.
  def self.discard(video)
    FileUtils.rm_rf(dir_for(video))
    video.update!(hls_ready_at: nil) if video.persisted? && video.hls_ready_at
  end

  private

  def package_video(source, staging)
    out = staging.join("video")
    FileUtils.mkdir_p(out)
    hls_run(
      [ "-i", source, "-map", "0:v:0", "-c", "copy", "-an" ],
      out
    )
  end

  # Track 1 (default) lives inside the MP4; alternates have their own .m4a.
  def package_audio(track, index, source, staging)
    out = staging.join("audio-#{index}")
    FileUtils.mkdir_p(out)

    if track.file.attached?
      track.file.open do |audio|
        hls_run([ "-i", audio.path, "-map", "0:a:0", "-c", "copy", "-vn" ], out)
      end
    else
      hls_run([ "-i", source, "-map", "0:a:0", "-c", "copy", "-vn" ], out)
    end
  end

  def hls_run(input_args, out_dir)
    _o, err, status = run(
      [ "ffmpeg", "-y", *input_args,
        "-f", "hls", "-hls_time", SEGMENT_SECONDS.to_s, "-hls_playlist_type", "vod",
        "-hls_segment_type", "fmp4", "-hls_flags", "independent_segments",
        "-hls_fmp4_init_filename", "init.mp4",
        "-hls_segment_filename", out_dir.join("seg_%04d.m4s").to_s,
        out_dir.join("index.m3u8").to_s ]
    )
    return true if status&.success? && File.size?(out_dir.join("index.m3u8"))

    Rails.logger.warn("HlsPackager rendition failed for #{@video.id}: #{err.to_s.lines.last(3).join.strip}")
    false
  end

  # The master playlist, by hand: video variant + one EXT-X-MEDIA per track,
  # names/languages verbatim from the AudioTrack rows.
  def write_master(tracks, staging, source)
    media = tracks.each_with_index.map do |track, index|
      attrs = [
        "TYPE=AUDIO", 'GROUP-ID="aud"',
        %(NAME="#{track.name.gsub('"', "'")}"),
        track.default? ? "DEFAULT=YES" : "DEFAULT=NO",
        "AUTOSELECT=YES",
        (%(LANGUAGE="#{track.language}") if track.language.present?),
        %(URI="audio-#{index}/index.m3u8")
      ].compact
      "#EXT-X-MEDIA:#{attrs.join(",")}"
    end

    staging.join("master.m3u8").write(<<~M3U8)
      #EXTM3U
      #EXT-X-VERSION:6
      #{media.join("\n")}
      #EXT-X-STREAM-INF:BANDWIDTH=#{estimated_bandwidth(source)},AUDIO="aud"
      video/index.m3u8
    M3U8
  end

  # BANDWIDTH is mandatory in EXT-X-STREAM-INF; with a single variant it only
  # needs to be the right order of magnitude.
  def estimated_bandwidth(source)
    duration = `ffprobe -v error -show_entries format=duration -of default=noprint_wrappers=1:nokey=1 #{source.shellescape}`.to_f
    return 2_000_000 if duration <= 0

    ((File.size(source) * 8) / duration * 1.1).round
  end

  def run(command, timeout: FFMPEG_TIMEOUT)
    Timeout.timeout(timeout) { Open3.capture3(*command) }
  rescue Timeout::Error
    Rails.logger.warn("HlsPackager: command timed out for #{@video.id}")
    [ nil, nil, nil ]
  end

  def failure(message)
    Result.new(status: :failed, renditions: 0, error: message)
  end
end
