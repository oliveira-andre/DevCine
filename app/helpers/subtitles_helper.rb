module SubtitlesHelper
  # Track descriptor array for the persistent player (feature 012):
  # [{ id, language, label, default, vttUrl }]. Used raw by the up-next JSON
  # (an in-place autoplay advance must carry its subtitle tracks along) and
  # JSON-encoded for the player page's data attribute.
  def subtitle_tracks_data(video, tracks)
    tracks.map do |track|
      {
        id: track.id,
        language: track.language,
        label: track.label,
        default: track.is_default,
        vttUrl: subtitle_player_path(video.slug, track.id)
      }
    end
  end

  def subtitle_tracks_json(video, tracks)
    subtitle_tracks_data(video, tracks).to_json
  end

  # Audio track descriptor array for the player's audio menu (MKV ingest):
  # [{ id, name, default, url }]. The default track has no url — its sound is
  # embedded in the video file itself; alternates stream their extracted .m4a
  # through redirect mode (range-safe, like the video).
  def audio_tracks_data(tracks)
    tracks.map do |track|
      {
        id: track.id,
        name: track.name,
        default: track.default?,
        url: (rails_storage_redirect_path(track.file) if track.file.attached?)
      }
    end
  end
end
