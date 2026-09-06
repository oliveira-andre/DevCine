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

  # Container/codec probes are quick; a remux is disk-bound (GBs of I/O) and
  # audio transcodes are ~faster than realtime — generous ceilings, they only
  # exist so a wedged ffmpeg can't hang a job forever.
  PROBE_TIMEOUT = 30
  FFMPEG_TIMEOUT = 3600

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
      else
        ensure_default_track
      end
    end
  rescue StandardError => e
    Rails.logger.warn("VideoIngest failed for video #{@video.id}: #{e.class}: #{e.message}")
    failure("ingest failed: #{e.message}")
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
  def ensure_default_track
    @video.audio_tracks.create!(name: "default", position: 1)
    Result.new(status: :default, audio_tracks: 1, subtitles: 0, error: nil)
  end

  def ingest_matroska(path, probed)
    audio_streams = probed["streams"].select { |s| s["codec_type"] == "audio" }
    return failure("mkv has no audio stream") if audio_streams.empty?

    Dir.mktmpdir("video-ingest") do |dir|
      mp4 = remux(path, audio_streams.first, dir)
      return failure("remux failed — file left untouched") if mp4.nil?

      subtitles = extract_subtitles(path, probed["streams"], dir)
      alternates = extract_alternate_audios(path, audio_streams, dir)

      replace_file!(mp4)
      create_audio_tracks!(audio_streams, alternates)

      Result.new(status: :remuxed, audio_tracks: audio_streams.size,
                 subtitles: subtitles, error: nil)
    end
  end

  # Video stream + first audio into a faststart MP4. -c:v copy always: H.264/
  # HEVC/VP9/AV1 all carry into MP4, and re-encoding video is off the table.
  def remux(path, first_audio, dir)
    out = File.join(dir, "remux.mp4")
    _o, err, status = run(
      [ "ffmpeg", "-y", "-i", path, "-map", "0:v:0", "-map", "0:a:0",
        "-c:v", "copy", *audio_codec_args(first_audio),
        "-movflags", "+faststart", "-sn", "-dn", out ],
      timeout: FFMPEG_TIMEOUT
    )
    return out if status&.success? && File.size?(out)

    Rails.logger.warn("VideoIngest remux failed for #{@video.id}: #{err.to_s.lines.last(3).join.strip}")
    nil
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
