class User < ApplicationRecord
  has_secure_password
  has_many :sessions, dependent: :destroy
  has_many :videos, dependent: :destroy
  has_many :video_views, dependent: :destroy
  has_many :watch_progress, dependent: :destroy
  has_many :comments, dependent: :destroy
  has_many :playlists, dependent: :destroy
  has_many :subscriptions, dependent: :destroy
  has_many :reviews, dependent: :destroy
  has_many :watchlist_items, dependent: :destroy
  has_many :likes, dependent: :destroy

  normalizes :email_address, with: ->(e) { e.strip.downcase }
end
