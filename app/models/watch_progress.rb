class WatchProgress < ApplicationRecord
  belongs_to :user
  belongs_to :video

  # A watch counts as completed within the last 5% of the runtime.
  COMPLETED_THRESHOLD = 0.95

  # Orders the personalized "Last watched" rail: most recently touched first.
  scope :recent_for, ->(user) { where(user: user).order(updated_at: :desc) }

  # Upsert the resume position for (user, video) — called periodically by the
  # player while watching. Marks completed near the end of the runtime.
  def self.record!(user, video, position:, duration: nil)
    position = [ position.to_i, 0 ].max
    progress = create_or_find_by!(user: user, video: video)
    completed = duration.to_i.positive? && position >= duration.to_i * COMPLETED_THRESHOLD
    progress.update!(position_seconds: position, completed: completed)
    progress
  end
end
