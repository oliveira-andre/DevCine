class Season < ApplicationRecord
  belongs_to :serie

  has_many :episodes, dependent: :destroy
  # Bridges Serie#videos (Serie -> seasons -> episodes -> video).
  has_many :videos, through: :episodes
end
