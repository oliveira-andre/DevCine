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
  # A saved copy points back at what it was saved from. optional: the original
  # may be deleted (the FK nullifies) and most playlists are not copies at all.
  belongs_to :cloned_from, class_name: "Playlist", optional: true
  has_many :clones, class_name: "Playlist", foreign_key: :cloned_from_id,
                    inverse_of: :cloned_from, dependent: :nullify

  has_many :playlist_items, dependent: :destroy
  has_many :videos, through: :playlist_items

  # A playlist always has a name; bounded to keep the UI sane (feature 008).
  validates :title, presence: true, length: { maximum: 100 }

  # Browsable/searchable playlists. Public only — "unlisted" means reachable by
  # link but never listed, so it must stay out of browse and search.
  scope :discoverable, -> { visibility_public }

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

  # The copy `user` already saved from this playlist, if any.
  def clone_for(user)
    return nil if user.nil?

    clones.find_by(user_id: user.id)
  end

  # Save a copy under `user`. Members come from ordered_video_ids, so a video
  # the saver cannot currently see is not copied — saving must not become a way
  # to obtain private or PIN-restricted titles. Visibility matches a
  # hand-created playlist (public), so a saved copy stays shareable.
  #
  # Returns the existing copy when there is one: saving twice is idempotent.
  def save_copy_for(user, auth_context)
    existing = clone_for(user)
    return existing if existing

    ids = ordered_video_ids(auth_context)

    transaction do
      copy = user.playlists.create!(title: title, visibility: :public, cloned_from: self)
      ids.each_with_index do |video_id, index|
        copy.playlist_items.create!(video_id: video_id, position: index + 1)
      end
      copy
    end
  end

  after_commit { Playlist.bump_version(order_cache_scope) }
end
