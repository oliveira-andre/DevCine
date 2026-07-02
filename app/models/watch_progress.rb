class WatchProgress < ApplicationRecord
  belongs_to :user
  belongs_to :video

  # Orders the personalized "Last watched" rail: most recently touched first.
  scope :recent_for, ->(user) { where(user: user).order(updated_at: :desc) }
end
