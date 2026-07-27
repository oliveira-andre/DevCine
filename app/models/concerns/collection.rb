# Shared behavior for a "collection" of videos — a Serie (Seasons → Episodes) or
# a Playlist (ordered PlaylistItems). Gives both a uniform surface used by the
# collection show pages (feature 007): canonical ordering, the Play/Continue
# target, and the current (most-recently-watched) video.
#
# Visibility is enforced through VideoPolicy::Scope (feature 006) — hidden and
# PIN-restricted videos are excluded from the list, the ordering, the Play
# target, and the hero thumbnail. Reads go through Rails.cache with version-aware
# keys (Constitution VI); the including model bumps its order version on write.
#
# The including model MUST:
#   - `extend Cacheable`
#   - define `raw_ordered_video_ids` → all member video ids in canonical order
#   - bump `order_cache_scope` in an `after_commit`
module Collection
  extend ActiveSupport::Concern

  # "serie" / "playlist" — used in cache keys and view branching.
  def collection_type
    model_name.element
  end

  def order_cache_scope
    [ "collection-order", collection_type, id ]
  end

  # Canonical, VISIBLE video ids in order. Cached per (collection, unlocked,
  # version); locked vs. unlocked yield different visible sets.
  def ordered_video_ids(auth_context)
    version = self.class.cache_version(order_cache_scope)
    self.class.cache_read([ "collection-order", collection_type, id, auth_context.pin_unlocked, version ]) do
      filter_visible(raw_ordered_video_ids, auth_context)
    end
  end

  # Hydrated videos (thumbnails eager-loaded), order preserved.
  def ordered_videos(auth_context, ids = nil)
    ids ||= ordered_video_ids(auth_context)
    return [] if ids.empty?

    Video.where(id: ids).with_attached_thumbnail.index_by(&:id).values_at(*ids).compact
  end

  def first_video(auth_context)
    Video.with_attached_thumbnail.find_by(id: ordered_video_ids(auth_context).first)
  end

  # The viewer's most-recently-watched VISIBLE video in this collection, or nil.
  # Cached per user, invalidated by VideoView's history version on every play.
  def current_video(user, auth_context)
    return if user.nil?

    ids = ordered_video_ids(auth_context)
    return if ids.empty?

    hist_version = VideoView.cache_version([ "history", user.id ])
    current_id = self.class.cache_read(
      [ "collection-current", collection_type, id, user.id, auth_context.pin_unlocked, hist_version ]
    ) do
      VideoView.where(user_id: user.id, video_id: ids).order(watched_at: :desc).pick(:video_id)
    end
    current_id && Video.with_attached_thumbnail.find_by(id: current_id)
  end

  # Where the Play/Continue action goes: resume the current video, else the
  # first. nil ⇒ empty collection ⇒ Play unavailable (FR-017).
  def play_target(user, auth_context)
    current_video(user, auth_context) || first_video(auth_context)
  end

  private

  # Keep only visible ids (VideoPolicy::Scope), preserving canonical order.
  def filter_visible(ids, auth_context)
    return [] if ids.empty?

    visible = VideoPolicy::Scope.new(auth_context, Video.where(id: ids)).resolve.pluck(:id).to_set
    ids.select { |vid| visible.include?(vid) }
  end
end
