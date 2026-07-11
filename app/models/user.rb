class User < ApplicationRecord
  has_secure_password

  enum :role, {
    user: 0,
    admin: 1,
    blocked: 2
  }

  has_many :sessions, dependent: :destroy
  has_many :uploaded_videos, class_name: "Video", foreign_key: :uploader_id,
                             inverse_of: :uploader, dependent: :destroy
  has_many :video_views, dependent: :destroy
  has_many :watch_progresses, dependent: :destroy
  has_many :comments, dependent: :destroy
  has_many :playlists, dependent: :destroy
  has_many :subscriptions, foreign_key: :subscriber_id, dependent: :destroy
  has_many :reviews, dependent: :destroy
  has_many :watchlist_items, dependent: :destroy
  has_many :likes, dependent: :destroy
  # Videos this member liked (the Likes rail on the profile).
  has_many :liked_videos, through: :likes, source: :likeable, source_type: "Video"

  # Media (Active Storage): profile avatar (falls back to initials when absent)
  # and an optional full-screen profile cover/background.
  has_one_attached :avatar
  has_one_attached :cover

  normalizes :email_address, with: ->(e) { e.strip.downcase }

  validates :email_address, presence: true, uniqueness: true
  validate :avatar_and_cover_are_images

  def avatar_and_cover_are_images
    { avatar: avatar, cover: cover }.each do |name, attachment|
      next unless attachment.attached?
      next if attachment.blob.content_type.to_s.start_with?("image/")

      errors.add(name, "must be an image")
    end
  end

  # Label shown next to / inside the rounded header avatar.
  def display_label
    display_name.presence || email_address
  end

  # Up to two uppercase initials derived from the display label, for the
  # avatar placeholder when no avatar image is attached.
  def initials
    source = display_name.presence || email_address.to_s.split("@").first.to_s
    parts = source.split(/[\s._-]+/).reject(&:blank?)
    letters = parts.first(2).map { |p| p[0] }
    letters = source[0, 2].chars if letters.empty?
    letters.join.upcase
  end
end
