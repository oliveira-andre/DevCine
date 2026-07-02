class Serie < ApplicationRecord
  extend FriendlyId
  friendly_id :title, use: :slugged

  enum :status, {
    ongoing: 0,
    ended: 1
  }

  enum :maturity_rating, {
    L: 0,
    A6: 1,
    A10: 2,
    A12: 3,
    A14: 4,
    A16: 5,
    A18: 6
  }

  has_many :seasons, dependent: :destroy
  has_many :videos, through: :seasons

  has_many :credits, as: :creditable, dependent: :destroy
  has_many :reviews, as: :reviewable, dependent: :destroy
  has_many :watchlist_items, as: :watchlistable, dependent: :destroy
  has_many :taggings, as: :taggable, dependent: :destroy

  has_many :people, through: :credits, source: :person
  has_many :genres, through: :taggings, source: :taggable, source_type: "Genre"

  # Media (Active Storage): card poster + optional backdrop (not used by the hero).
  has_one_attached :poster
  has_one_attached :backdrop

  validates :title, presence: true

  # Recency for the "Recently added series" rail.
  scope :recent, -> { order(created_at: :desc) }
end
