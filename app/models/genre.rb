class Genre < ApplicationRecord
  extend FriendlyId
  friendly_id :name, use: :slugged

  has_many :taggings, dependent: :destroy
  has_many :movies, through: :taggings, source: :taggable, source_type: "Movie"
  has_many :series, through: :taggings, source: :taggable, source_type: "Serie"
end
