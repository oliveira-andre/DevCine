class Subtitle < ApplicationRecord
  belongs_to :video

  # Media (Active Storage): the caption/subtitle file.
  has_one_attached :file
end
