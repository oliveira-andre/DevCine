class Episode < ApplicationRecord
  belongs_to :season, touch: true
  belongs_to :video

  has_many :credits, as: :creditable, dependent: :destroy
  has_many :people, through: :credits, source: :person
  has_many :reviews, as: :reviewable, dependent: :destroy

  # An episode add/remove/reorder changes its serie's ordered video list (007).
  after_commit { Serie.bump_version([ "collection-order", "serie", season.serie_id ]) if season }
end
