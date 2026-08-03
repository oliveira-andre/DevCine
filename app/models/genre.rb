class Genre < ApplicationRecord
  extend FriendlyId
  extend Cacheable
  friendly_id :name, use: :slugged

  has_many :taggings, dependent: :destroy
  has_many :movies, through: :taggings, source: :taggable, source_type: "Movie"
  has_many :series, through: :taggings, source: :taggable, source_type: "Serie"

  # Admin-editable since feature 013; the slug is unique, and a duplicate name
  # would just collide there, so guard the name too. Case-insensitive so
  # "Drama" and "drama" can't both exist.
  validates :name, presence: true, length: { maximum: 60 },
                   uniqueness: { case_sensitive: false }

  CACHE_SCOPE = [ "genres" ].freeze
  after_commit { Genre.bump_version(CACHE_SCOPE) }

  # Cached alphabetical list for the catalog filter pills (feature 011,
  # Constitution VI). Invalidated whenever a genre is created/updated/destroyed.
  def self.pill_list
    cache_read([ "genres", "pills", cache_version(CACHE_SCOPE) ]) { order(:name).to_a }
  end
end
