class Playlist < ApplicationRecord
  # Same visibility scale as Video; prefixed to avoid the private/public
  # collision with Ruby's Module methods.
  enum :visibility, {
    private: 0,
    public: 1,
    unlisted: 2
  }, prefix: true

  belongs_to :user

  has_many :playlist_items, dependent: :destroy
  has_many :videos, through: :playlist_items

  # Video count shown on the profile Playlists rail.
  def videos_count
    playlist_items.size
  end
end
