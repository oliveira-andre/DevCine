# Saves the viewer's audio/subtitle choice for the playing video's TITLE
# (Serie for episodes, Movie for features, the Video itself for standalones).
# One row per (user, title) — find_or_initialize + the unique index make every
# later change an UPDATE of the same row, never a new one.
class PlaybackPreferencesController < ApplicationController
  include Playable

  def update
    video = find_playable_video!
    scope = video.preference_scope

    preference = Current.user.playback_preferences.find_or_initialize_by(watchable: scope)
    preference.audio_track_name = params[:audio_track_name].presence if params.key?(:audio_track_name)
    preference.subtitle_language = params[:subtitle_language].presence if params.key?(:subtitle_language)
    preference.save!

    head :no_content
  rescue ActiveRecord::RecordNotUnique
    # Two players racing on the first save — the row exists now; retry as update.
    retry
  end
end
