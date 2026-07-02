class VideoRendition < ApplicationRecord
  enum :format, {
    mp4: 0,
    webm: 1,
    mkv: 2,
    avi: 3
  }

  belongs_to :video

  # Media (Active Storage): the encoded rendition file.
  has_one_attached :file

  validates :resolution, presence: true
end
