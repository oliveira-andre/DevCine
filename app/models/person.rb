class Person < ApplicationRecord
  has_many :credits, dependent: :destroy

  # Media (Active Storage): headshot / profile photo.
  has_one_attached :photo
end
