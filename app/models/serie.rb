class Serie < ApplicationRecord
  has_many :seasons, dependent: :destroy
  has_many :videos, through: :seasons

  has_many :credits, as: :creditable, dependent: :destroy
  has_many :reviews, as: :reviewable, dependent: :destroy
  has_many :watchlist_items, as: :watchlistable, dependent: :destroy
  has_many :taggings, as: :taggable, dependent: :destroy

  has_many :people, through: :credits, source: :person
  has_many :genres, through: :taggings, source: :taggable, source_type: "Genre"
end
