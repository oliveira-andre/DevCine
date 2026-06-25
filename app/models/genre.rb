class Genre < ApplicationRecord
  has_many :taggings, dependent: :destroy
  has_many :movies, through: :taggings, source: :taggable, source_type: "Movie"
  has_many :series, through: :taggings, source: :taggable, source_type: "Serie"
end
