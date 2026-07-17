class Like < ApplicationRecord
  extend Cacheable

  # A reaction to a video or comment: like (up) or dislike (down). One row per
  # (user, likeable) — toggling switches or removes it.
  enum :kind, { like: 0, dislike: 1 }, prefix: :reaction

  belongs_to :user
  belongs_to :likeable, polymorphic: true

  # Keep the user's real "Videos you liked" playlist in sync (FR-022): only
  # positive reactions to videos belong there.
  after_commit :sync_liked_playlist
  after_commit :remove_from_liked_playlist, on: :destroy

  private

  def sync_liked_playlist
    return if destroyed?
    return unless likeable_type == "Video"

    if reaction_like?
      add_to_liked_playlist
    else
      delete_liked_playlist_item # a dislike must not sit in "Videos you liked"
    end
    Like.bump_version([ "liked", user_id ])
  end

  def add_to_liked_playlist
    playlist = user.liked_playlist
    return if playlist.playlist_items.exists?(video_id: likeable_id)

    next_position = (playlist.playlist_items.maximum(:position) || 0) + 1
    playlist.playlist_items.create!(video_id: likeable_id, position: next_position)
  end

  def remove_from_liked_playlist
    return unless likeable_type == "Video"

    delete_liked_playlist_item
    Like.bump_version([ "liked", user_id ])
  end

  def delete_liked_playlist_item
    playlist = user.playlists.find_by(title: User::LIKED_PLAYLIST_TITLE)
    playlist&.playlist_items&.where(video_id: likeable_id)&.destroy_all
  end
end
