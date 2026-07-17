class PlaylistAdditionsController < ApplicationController
  include Playable
  include ModalLayout

  # GET /playing/:slug/add-to-playlist — modal listing the user's playlists with
  # add/remove toggles for this video (feature 005 enhancement).
  def new
    @video = find_playable_video!
    @playlists = Current.user.playlists.order(:title)
  end

  # POST /playlists/:playlist_id/toggle/:slug — add or remove the video from the
  # playlist; Turbo-Stream re-renders just that row.
  def create
    @video = find_playable_video! # enforce visibility (avoid IDOR on private videos)
    @playlist = Current.user.playlists.find(params[:playlist_id])
    toggle_membership(@playlist, @video)

    render turbo_stream: turbo_stream.replace(
      "playlist_row_#{@playlist.id}",
      partial: "playlist_additions/row", locals: { playlist: @playlist, video: @video }
    )
  end

  private

  def toggle_membership(playlist, video)
    item = playlist.playlist_items.find_by(video: video)
    if item
      item.destroy
    else
      position = (playlist.playlist_items.maximum(:position) || 0) + 1
      playlist.playlist_items.create!(video: video, position: position)
    end
  end
end
