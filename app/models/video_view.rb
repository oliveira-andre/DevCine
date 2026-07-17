class VideoView < ApplicationRecord
  extend Cacheable

  belongs_to :video
  belongs_to :user

  # Watch history keeps at most the 300 most-recent distinct videos per user.
  HISTORY_LIMIT = 300

  scope :recent_for, ->(user) { where(user: user).order(watched_at: :desc) }

  # Record (or refresh) a watch-history entry on playback start (FR-018). One row
  # per (user, video) — re-watching just refreshes watched_at — capped at
  # HISTORY_LIMIT, oldest pruned.
  def self.record!(user, video)
    entry = create_or_find_by!(user: user, video: video)
    entry.update!(watched_at: Time.current)
    prune!(user)
    entry
  end

  # Delete the user's rows beyond the HISTORY_LIMIT most-recent.
  def self.prune!(user)
    keep_ids = recent_for(user).limit(HISTORY_LIMIT).pluck(:id)
    where(user: user).where.not(id: keep_ids).delete_all
  end

  # The virtual "Watch History" playlist: the user's history, newest → oldest.
  def self.history_for(user, limit: HISTORY_LIMIT)
    recent_for(user).limit(limit)
  end

  after_commit :bump_history_cache

  private

  def bump_history_cache
    VideoView.bump_version([ "history", user_id ])
  end
end
