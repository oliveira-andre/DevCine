class User < ApplicationRecord
  has_secure_password
  # Restricted-content PIN (feature 006): bcrypt into pin_digest; never readable
  # back. `authenticate_pin` is the only way to check it.
  has_secure_password :pin, validations: false

  # The auto-managed private playlist that mirrors the user's likes (feature 005).
  LIKED_PLAYLIST_TITLE = "Videos you liked".freeze
  # Consecutive wrong-PIN limit before the account is blocked (tunable; default 3).
  PIN_MAX_ATTEMPTS = 3
  # Consecutive wrong-password limit before sign-in is locked until a reset.
  LOGIN_MAX_ATTEMPTS = 15

  enum :role, {
    user: 0,
    admin: 1,
    blocked: 2
  }

  has_many :sessions, dependent: :destroy
  # Remembered audio/subtitle choices, one per title (feature: playback prefs).
  has_many :playback_preferences, dependent: :destroy
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

  # Subtitle appearance preferences (feature 012). Background may be blank/nil =
  # transparent; colors are #RRGGBB.
  SUBTITLE_FONT_WEIGHTS = [ 100, 200, 300, 400, 500, 600, 700, 800, 900 ].freeze
  validates :subtitle_text_color, format: { with: /\A#\h{6}\z/ }, allow_blank: true
  validates :subtitle_background_color, format: { with: /\A#\h{6}\z/ }, allow_blank: true
  validates :subtitle_font_size, numericality: { only_integer: true, in: 50..300 }
  validates :subtitle_font_weight, inclusion: { in: SUBTITLE_FONT_WEIGHTS }
  # PIN format is validated only when a PIN is being set (FR-013).
  validates :pin, format: { with: /\A\d{4,6}\z/, message: "must be 4 to 6 digits" },
                  confirmation: { message: "doesn't match" }, if: -> { pin.present? }

  # Every user gets a private "Videos you liked" playlist (FR-022).
  after_create :create_liked_playlist
  # Setting a new password (the reset link from the lock email, or any other
  # change) lifts a login lock. Deliberately separate from the `blocked` role:
  # a reset must never undo an admin ban or demote an admin.
  before_save :clear_login_lock, if: :will_save_change_to_password_digest?

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

  # --- Sign-in lockout ---

  def login_locked?
    locked_at.present?
  end

  def can_sign_in?
    !blocked? && !login_locked?
  end

  # Count a wrong password. The LOGIN_MAX_ATTEMPTS-th locks sign-in and emails
  # a reset link. Banned or already-locked accounts aren't counted, so a banned
  # user never gets an "unlock" email.
  def register_failed_login!
    return if blocked? || login_locked?

    increment!(:failed_login_attempts)
    lock_login! if failed_login_attempts >= LOGIN_MAX_ATTEMPTS
  end

  def reset_failed_logins!
    update_columns(failed_login_attempts: 0) if failed_login_attempts.positive?
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

  # Conditional on locked_at still being nil so concurrent failures lock (and
  # email) exactly once.
  def lock_login!
    now = Time.current
    return unless self.class.where(id: id, locked_at: nil).update_all(locked_at: now).positive?

    self.locked_at = now
    PasswordsMailer.unlock(self).deliver_later
  end

  def clear_login_lock
    self.failed_login_attempts = 0
    self.locked_at = nil
  end
end
