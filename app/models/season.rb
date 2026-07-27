class Season < ApplicationRecord
  belongs_to :serie, touch: true

  has_many :episodes, dependent: :destroy
  # Bridges Serie#videos (Serie -> seasons -> episodes -> video).
  has_many :videos, through: :episodes

  def ordered_episodes
    episodes.order(:position)
  end

  # A season add/remove/reorder changes the serie's ordered video list (007).
  after_commit { Serie.bump_version([ "collection-order", "serie", serie_id ]) }
end
