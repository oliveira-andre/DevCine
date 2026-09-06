require "open3"

# MKV ingest (browser playback + track stripping). Browsers can't be trusted
# with Matroska: the container is unsupported outside Chrome, its extra audio
# tracks are unreachable, and embedded subtitles are ignored. So after upload:
#
#   MKV      → remux the video + FIRST audio into a faststart MP4 (video stream
#              is NEVER re-encoded — `-c:v copy`; audio is copied when already
#              AAC, transcoded to AAC otherwise, since MKVs love AC-3/DTS which
#              browsers won't play), replace the video's file with it, strip
#              every audio track into a named AudioTrack row (first = default,
#              names from the container's own title/language tags), and pull
#              every text subtitle out as an SRT into the existing Subtitle
#              system (language tags mapped onto the Subtitle enum).
#   non-MKV  → just guarantee a single AudioTrack row named "default".
#
# Best-effort like the rest of the media pipeline: any ffmpeg failure leaves
# the original file untouched and reports an error instead of raising.
class VideoIngest
  Result = Data.define(:status, :audio_tracks, :subtitles, :error) do
    def ok? = error.nil?
  end

  # Container/codec probes are quick; a remux is disk-bound (GBs of I/O), and a
  # full VIDEO transcode (HEVC/10-bit → H.264) can run below realtime on a VPS,
  # so the ffmpeg ceiling is generous — it only exists so a wedged process
  # can't hang a job forever.
  PROBE_TIMEOUT = 30
  FFMPEG_TIMEOUT = 6 * 3600

  # What every mainstream browser decodes without OS/GPU luck: H.264 in 8-bit
  # 4:2:0, VP9 or AV1. HEVC (macOS-only in practice) and 10-bit anything
  # (anime's beloved Main 10 / Hi10P) must be re-encoded.
  SAFE_PIXEL_FORMATS = %w[yuv420p yuvj420p].freeze

  TEXT_SUBTITLE_CODECS = %w[subrip ass ssa mov_text webvtt text].freeze

  # ISO 639 tags (2/3-letter, common variants) → Subtitle.language enum keys.
  SUBTITLE_LANGUAGES = {
    "eng" => "english", "en" => "english",
    "spa" => "spanish", "es" => "spanish",
    "por" => "portuguese", "pob" => "portuguese", "pt" => "portuguese",
    "fre" => "french", "fra" => "french", "fr" => "french",
    "ger" => "german", "deu" => "german", "de" => "german",
    "ita" => "italian", "it" => "italian",
    "jpn" => "japanese", "ja" => "japanese",
    "kor" => "korean", "ko" => "korean",
    "chi" => "chinese", "zho" => "chinese", "zh" => "chinese",
    "ara" => "arabic", "ar" => "arabic",
    "rus" => "russian", "ru" => "russian",
    "hin" => "hindi", "hi" => "hindi"
  }.freeze

  def self.call(video)
    new(video).call
  end

  def initialize(video)
    @video = video
  end

  def call
    return failure("no video file attached") unless @video.file.attached?
    return failure("ffmpeg is unavailable") unless VideoFrameExtractor.available?
    return Result.new(status: :skipped, audio_tracks: 0, subtitles: 0, error: nil) if @video.audio_tracks.exists?

    @video.file.open do |source|
      streams = probe(source.path)
      return failure("could not probe the file") if streams.nil?

      if matroska?(streams)
        ingest_matroska(source.path, streams)
      elsif unsafe_video?(streams)
        # Right container, undecodable codec (an HEVC/10-bit MP4): re-encode
        # in place, then the default track row as for any non-MKV upload.
        replace_with_playable(source.path, streams) || ensure_default_track(status: :transcoded)
      else
        ensure_default_track
      end
    end
  rescue StandardError => e
    Rails.logger.warn("VideoIngest failed for video #{@video.id}: #{e.class}: #{e.message}")
    failure("ingest failed: #{e.message}")
  end

  # Fix an ALREADY-ingested (or pre-feature) file whose video codec browsers
  # can't decode — HEVC / 10-bit, playable on macOS only. Replaces the file
  # with an H.264 8-bit MP4; audio tracks and subtitles are left untouched
  # (they were extracted at ingest). No-op (:safe) for decodable files.
  def reencode
    return failure("no video file attached") unless @video.file.attached?
    return failure("ffmpeg is unavailable") unless VideoFrameExtractor.available?

    @video.file.open do |source|
      streams = probe(source.path)
      return failure("could not probe the file") if streams.nil?
      return Result.new(status: :safe, audio_tracks: 0, subtitles: 0, error: nil) unless unsafe_video?(streams)

      replace_with_playable(source.path, streams) ||
        Result.new(status: :transcoded, audio_tracks: 0, subtitles: 0, error: nil)
    end
  rescue StandardError => e
    Rails.logger.warn("VideoIngest reencode failed for video #{@video.id}: #{e.class}: #{e.message}")
    failure("reencode failed: #{e.message}")
  end

  def self.reencode(video)
    new(video).reencode
  end

  private

  def probe(path)
    out, _err, status = run(
      [ "ffprobe", "-v", "error", "-print_format", "json", "-show_format", "-show_streams", path ],
      timeout: PROBE_TIMEOUT
    )
    return nil unless status&.success?

    JSON.parse(out)
  rescue JSON::ParserError
    nil
  end

  def matroska?(probed)
    probed.dig("format", "format_name").to_s.include?("matroska")
  end

  # Non-MKV: nothing to strip — the row just names the embedded audio.
  def ensure_default_track(status: :default)
    @video.audio_tracks.create!(name: "default", position: 1)
    Result.new(status: status, audio_tracks: 1, subtitles: 0, error: nil)
  end

  def first_stream(probed, type)
    probed["streams"].find { |s| s["codec_type"] == type }
  end

  def unsafe_video?(probed)
    stream = first_stream(probed, "video")
    stream.present? && !browser_safe_video?(stream)
  end

  # What every mainstream browser decodes: H.264 in 8-bit 4:2:0, VP9 or AV1.
  # HEVC only decodes where the OS/GPU happens to help (macOS, some Windows
  # boxes — not Brave), and 10-bit H.264 (Hi10P) decodes nowhere.
  def browser_safe_video?(stream)
    case stream["codec_name"]
    when "vp9", "av1" then true
    when "h264" then SAFE_PIXEL_FORMATS.include?(stream["pix_fmt"].to_s)
    else false
    end
  end

  def ingest_matroska(path, probed)
    audio_streams = probed["streams"].select { |s| s["codec_type"] == "audio" }
    return failure("mkv has no audio stream") if audio_streams.empty?

    Dir.mktmpdir("video-ingest") do |dir|
      mp4 = build_mp4(path, first_stream(probed, "video"), audio_streams.first, dir)
      return failure("remux failed — file left untouched") if mp4.nil?

      subtitles = extract_subtitles(path, probed["streams"], dir)
      alternates = extract_alternate_audios(path, audio_streams, dir)

      replace_file!(mp4)
      create_audio_tracks!(audio_streams, alternates)

      Result.new(status: :remuxed, audio_tracks: audio_streams.size,
                 subtitles: subtitles, error: nil)
    end
  end

  # Re-encode the current file to a playable MP4 and swap it in. Returns nil on
  # success so callers can chain their success Result after `||`; on failure
  # returns the failure Result (original file untouched).
  def replace_with_playable(path, probed)
    Dir.mktmpdir("video-ingest") do |dir|
      mp4 = build_mp4(path, first_stream(probed, "video"), first_stream(probed, "audio"), dir)
      return failure("transcode failed — file left untouched") if mp4.nil?

      replace_file!(mp4)
    end
    nil
  end

  # Video + first audio into a faststart MP4. Video is copied when browsers can
  # decode it and re-encoded to H.264 8-bit otherwise; audio is copied when
  # already AAC, transcoded to AAC otherwise.
  def build_mp4(path, video_stream, audio_stream, dir)
    out = File.join(dir, "remux.mp4")
    maps = [ "-map", "0:v:0" ]
    maps += [ "-map", "0:a:0" ] if audio_stream
    _o, err, status = run(
      [ "ffmpeg", "-y", "-i", path, *maps,
        *video_codec_args(video_stream), *(audio_stream ? audio_codec_args(audio_stream) : []),
        "-movflags", "+faststart", "-sn", "-dn", out ],
      timeout: FFMPEG_TIMEOUT
    )
    return out if status&.success? && File.size?(out)

    Rails.logger.warn("VideoIngest build_mp4 failed for #{@video.id}: #{err.to_s.lines.last(3).join.strip}")
    nil
  end

  def video_codec_args(stream)
    if stream && browser_safe_video?(stream)
      [ "-c:v", "copy" ]
    else
      # CRF 23 veryfast: visually transparent, ~realtime-ish on a VPS core.
      [ "-c:v", "libx264", "-preset", "veryfast", "-crf", "23", "-pix_fmt", "yuv420p" ]
    end
  end

  def audio_codec_args(stream)
    stream["codec_name"] == "aac" ? [ "-c:a", "copy" ] : [ "-c:a", "aac", "-b:a", "192k" ]
  end

  # Every audio track AFTER the first, stripped to its own .m4a. Returns
  # { audio-relative-index => path } for the ones that extracted cleanly.
  def extract_alternate_audios(path, audio_streams, dir)
    audio_streams.each_with_index.drop(1).filter_map do |stream, index|
      out = File.join(dir, "audio-#{index}.m4a")
      _o, _e, status = run(
        [ "ffmpeg", "-y", "-i", path, "-map", "0:a:#{index}", "-vn",
          *audio_codec_args(stream), out ],
        timeout: FFMPEG_TIMEOUT
      )
      [ index, out ] if status&.success? && File.size?(out)
    end.to_h
  end

  def create_audio_tracks!(audio_streams, alternates)
    audio_streams.each_with_index do |stream, index|
      track = @video.audio_tracks.create!(
        name: track_name(stream, index),
        language: stream.dig("tags", "language").presence,
        position: index + 1
      )
      next unless (file = alternates[index])

      track.file.attach(io: File.open(file, "rb"),
                        filename: "#{track_name(stream, index).parameterize.presence || "audio-#{index + 1}"}.m4a",
                        content_type: "audio/mp4")
    end
  end

  # The container's own naming, as requested: title tag, else language tag,
  # else a numbered fallback.
  def track_name(stream, index)
    stream.dig("tags", "title").presence ||
      stream.dig("tags", "language").presence ||
      "Audio #{index + 1}"
  end

  # Text subtitle tracks → SRT files → the existing Subtitle system. Bitmap
  # subs (PGS/VobSub) can't become SRT without OCR and are skipped, as are
  # languages outside the Subtitle enum.
  def extract_subtitles(path, streams, dir)
    subtitle_streams = streams.select { |s| s["codec_type"] == "subtitle" }
    created = 0

    subtitle_streams.each_with_index do |stream, index|
      next unless TEXT_SUBTITLE_CODECS.include?(stream["codec_name"])

      language = SUBTITLE_LANGUAGES[stream.dig("tags", "language").to_s.downcase]
      if language.nil?
        Rails.logger.info("VideoIngest: skipping subtitle track #{index} of #{@video.id} — unmapped language #{stream.dig("tags", "language").inspect}")
        next
      end
      next if @video.subtitles.exists?(language: language)

      out = File.join(dir, "sub-#{index}.srt")
      _o, _e, status = run(
        [ "ffmpeg", "-y", "-i", path, "-map", "0:s:#{index}", "-c:s", "srt", out ],
        timeout: FFMPEG_TIMEOUT
      )
      next unless status&.success? && File.size?(out)

      name = stream.dig("tags", "title").presence || language
      subtitle = @video.subtitles.new(language: language, is_default: created.zero? && @video.subtitles.none?)
      subtitle.file.attach(io: File.open(out, "rb"),
                           filename: "#{name.parameterize.presence || language}.srt",
                           content_type: "application/x-subrip")
      subtitle.save ? created += 1 : Rails.logger.warn("VideoIngest: subtitle #{language} invalid for #{@video.id}")
    end

    created
  end

  # Swap the attachment for the remuxed MP4 (same basename, .mp4 extension).
  def replace_file!(mp4)
    basename = File.basename(@video.file.filename.to_s, ".*")
    @video.file.attach(io: File.open(mp4, "rb"),
                       filename: "#{basename}.mp4", content_type: "video/mp4")
  end

  def run(command, timeout:)
    Timeout.timeout(timeout) { Open3.capture3(*command) }
  rescue Timeout::Error
    Rails.logger.warn("VideoIngest: command timed out for #{@video.id}: #{command.first(4).join(" ")}…")
    [ nil, nil, nil ]
  end

  def failure(message)
    Result.new(status: :failed, audio_tracks: 0, subtitles: 0, error: message)
  end
end
