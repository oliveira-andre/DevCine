class Playlist < ApplicationRecord
  extend Cacheable
  include Collection

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

  # A playlist always has a name; bounded to keep the UI sane (feature 008).
  validates :title, presence: true, length: { maximum: 100 }

  # Video count shown on the profile Playlists rail.
  def videos_count
    playlist_items.size
  end

  # The auto-managed "Videos you liked" playlist is system-owned and cannot be
  # user-deleted (feature 008 delete).
  def system?
    title == User::LIKED_PLAYLIST_TITLE
  end

  # All member video ids in canonical (playlist position) order — filtered to
  # the visible set + cached by Collection#ordered_video_ids.
  def raw_ordered_video_ids
    playlist_items.order(:position).pluck(:video_id)
  end

  after_commit { Playlist.bump_version(order_cache_scope) }
end
