class User < ApplicationRecord
  has_secure_password
  # Restricted-content PIN (feature 006): bcrypt into pin_digest; never readable
  # back. `authenticate_pin` is the only way to check it.
  has_secure_password :pin, validations: false

  # The auto-managed private playlist that mirrors the user's likes (feature 005).
  LIKED_PLAYLIST_TITLE = "Videos you liked".freeze
  # Consecutive wrong-PIN limit before the account is blocked (tunable; default 3).
  PIN_MAX_ATTEMPTS = 3

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
  # Videos this member liked (the Likes rail on the profile) — positive
  # reactions only (dislikes excluded).
  has_many :liked_videos, -> { where(likes: { kind: Like.kinds[:like] }) },
           through: :likes, source: :likeable, source_type: "Video"

  # Media (Active Storage): profile avatar (falls back to initials when absent)
  # and an optional full-screen profile cover/background.
  has_one_attached :avatar
  has_one_attached :cover

  normalizes :email_address, with: ->(e) { e.strip.downcase }

  validates :email_address, presence: true, uniqueness: true
  validate :avatar_and_cover_are_images
  # PIN format is validated only when a PIN is being set (FR-013).
  validates :pin, format: { with: /\A\d{4,6}\z/, message: "must be 4 to 6 digits" },
                  confirmation: { message: "doesn't match" }, if: -> { pin.present? }

  # Every user gets a private "Videos you liked" playlist (FR-022).
  after_create :create_liked_playlist

  # The user's real, private "Videos you liked" playlist. Lazily created for
  # users that predate this feature.
  def liked_playlist
    playlists.find_or_create_by!(title: LIKED_PLAYLIST_TITLE) do |playlist|
      playlist.visibility = :private
    end
  end

  # --- Restricted-content PIN (feature 006) ---

  def pin?
    pin_digest.present?
  end

  # Count a consecutive wrong PIN. Reaching PIN_MAX_ATTEMPTS blocks the account
  # (existing role; sign-in already rejects blocked users). Returns :blocked or
  # :failed so the controller can end the session on the final strike.
  def register_failed_pin_attempt!
    increment!(:pin_attempts)
    if pin_attempts >= PIN_MAX_ATTEMPTS
      update!(role: :blocked)
      :blocked
    else
      :failed
    end
  end

  def reset_pin_attempts!
    update!(pin_attempts: 0)
  end

  def remaining_pin_attempts
    [ PIN_MAX_ATTEMPTS - pin_attempts, 0 ].max
  end

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

  private

  def create_liked_playlist
    playlists.create!(title: LIKED_PLAYLIST_TITLE, visibility: :private)
  end
end
