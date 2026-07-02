class Movie < ApplicationRecord
  belongs_to :video
  belongs_to :trailer, class_name: "Video", optional: true

  has_many :credits, as: :creditable, dependent: :destroy
  has_many :reviews, as: :reviewable, dependent: :destroy
  has_many :watchlist_items, as: :watchlistable, dependent: :destroy
  has_many :taggings, as: :taggable, dependent: :destroy

  has_many :people, through: :credits, source: :person
  has_many :genres, through: :taggings, source: :taggable, source_type: "Genre"

  # Media (Active Storage): card poster + hero backdrop.
  has_one_attached :poster
  has_one_attached :backdrop

  # Recency for the "Recently added movies" rail.
  scope :recent, -> { order(created_at: :desc) }
  # The four newest movies power the hero banner (FR-004/FR-005).
  scope :hero, -> { recent.limit(4) }

  # Hero/background image source, in priority order:
  #   attached Active Storage backdrop -> external backdrop_key URL -> nil.
  def backdrop_image
    return backdrop if backdrop.attached?
    backdrop_key.presence
  end
end
