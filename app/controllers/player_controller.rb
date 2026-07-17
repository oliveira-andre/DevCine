class PlayerController < ApplicationController
  include Playable

  # GET /playing/:slug — the full-bleed player page (feature 005, US1).
  def show
    @video = find_playable_video!(scope: Video.with_attached_file.with_attached_thumbnail)
    # Resume where the viewer stopped (skip when they finished the video).
    progress = WatchProgress.find_by(user: Current.user, video: @video)
    @resume_position = progress&.completed ? 0 : progress&.position_seconds.to_i
  end

  # GET /playing/:slug/related — lazy Turbo Frame content (US8, FR-028).
  def related
    @video = find_playable_video!
    @related = @video.related(pundit_user, limit: 12)
  end
end
