class VideoViewsController < ApplicationController
  include Playable

  # POST /playing/:slug/views — record the video in the viewer's watch history
  # on playback start (feature 005, US6). Called once by the player on first play.
  def create
    video = find_playable_video!
    VideoView.record!(Current.user, video)
    head :no_content
  end
end
