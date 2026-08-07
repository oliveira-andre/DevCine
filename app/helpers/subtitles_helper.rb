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
end
