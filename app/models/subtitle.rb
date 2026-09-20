class Subtitle < ApplicationRecord
  extend Cacheable

  belongs_to :video

  # Media (Active Storage): the caption/subtitle SRT file.
  has_one_attached :file

  # Feature 012: the track's language. Integer-backed (existing column).
  enum :language, {
    english: 0, spanish: 1, portuguese: 2, french: 3, german: 4,
    italian: 5, japanese: 6, korean: 7, chinese: 8, arabic: 9,
    russian: 10, hindi: 11
  }

  validates :language, presence: true
  validate :srt_file_present

  # Only one default track per video (FR-013).
  before_save :unset_other_defaults, if: -> { is_default? && will_save_change_to_is_default? }
  # A track change alters the video's cached track list (Constitution VI).
  after_commit :bust_track_cache

  # Human-readable track name (e.g. "Portuguese").
  def label
    language.to_s.titleize
  end

  # The track as WebVTT for the browser <track> element. SRT and VTT differ only
  # by a header and the decimal separator in timestamps; convert on the fly and
  # cache by blob key (a new file ⇒ new key ⇒ fresh cache; "v2" = sanitizer
  # added, so already-cached dirty output is left behind).
  def to_vtt
    return "" unless file.attached?

    Subtitle.cache_read([ "subtitle-vtt", "v2", file.blob.key ]) do
      # download returns ASCII-8BIT bytes; SRT files are UTF-8, so reinterpret
      # them as UTF-8 (else non-ASCII captions raise an encoding error on interp).
      body = file.download.dup.force_encoding(Encoding::UTF_8)
      # Files ingested before the sanitizer (or uploaded by hand) may still
      # carry ffmpeg's ASS→SRT styling junk — clean at render time too.
      body = SubtitleSanitizer.call(body)
      body.gsub!(/(\d{2}:\d{2}:\d{2}),(\d{3})/, '\1.\2') # SRT comma → VTT dot
      "WEBVTT\n\n#{body}"
    end
  end

  private

  def srt_file_present
    unless file.attached?
      errors.add(:file, "must be an SRT file")
      return
    end
    name = file.blob&.filename.to_s.downcase
    errors.add(:file, "must be an .srt file") unless name.end_with?(".srt")
  end

  def unset_other_defaults
    video.subtitles.where.not(id: id).update_all(is_default: false)
  end

  def bust_track_cache
    Subtitle.bump_version([ "subtitles", video_id ])
  end
end
