class WatchProgressesController < ApplicationController
  include Playable

  # POST /playing/:slug/progress — save the viewer's resume position. Called by
  # the player every ~10s while playing, on pause, and on pagehide. Feeds the
  # home "Last watched" rail and resume-on-return.
  def create
    video = find_playable_video!
    WatchProgress.record!(
      Current.user, video,
      position: params[:position], duration: params[:duration]
    )
    head :no_content
  end
end
