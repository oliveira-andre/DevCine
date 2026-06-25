class Episode < ApplicationRecord
  belongs_to :season
  belongs_to :video

  has_many :credits, as: :creditable, dependent: :destroy
  has_many :people, through: :credits, source: :person
  has_many :reviews, as: :reviewable, dependent: :destroy
end
