class Comment < ApplicationRecord
  extend Cacheable
  include Reactable

  belongs_to :user
  belongs_to :video
  belongs_to :parent, class_name: "Comment", optional: true

  has_many :replies, class_name: "Comment", foreign_key: :parent_id, dependent: :destroy
  has_many :likes, as: :likeable, dependent: :destroy

  validates :body, presence: true

  # Top-level comments for a video, newest-first (replies are nested — FR-025).
  scope :for_video, ->(video) { where(video: video, parent_id: nil).order(created_at: :desc) }

  # A comment is "long" when its body has more than 3 paragraphs (blocks split
  # on blank lines) — drives the per-comment read-more (FR-025).
  def long?
    body.to_s.split(/\n\s*\n/).map(&:strip).reject(&:blank?).size > 3
  end

  def reply?
    parent_id.present?
  end

  after_commit :bump_comments_cache

  private

  def bump_comments_cache
    Comment.bump_version([ "comments", video_id ])
  end
end
