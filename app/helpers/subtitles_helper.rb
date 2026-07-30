module SubtitlesHelper
  # JSON track descriptor for the persistent player (feature 012):
  # [{ id, language, label, default, vttUrl }].
  def subtitle_tracks_json(video, tracks)
    tracks.map do |track|
      {
        id: track.id,
        language: track.language,
        label: track.label,
        default: track.is_default,
        vttUrl: subtitle_player_path(video.slug, track.id)
      }
    end.to_json
  end
end
