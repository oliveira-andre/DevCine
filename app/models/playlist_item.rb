class PlaylistItem < ApplicationRecord
  belongs_to :playlist, touch: true
  belongs_to :video

  # An item add/remove/reorder changes the playlist's ordered video list (007).
  after_commit { Playlist.bump_version([ "collection-order", "playlist", playlist_id ]) }
end
