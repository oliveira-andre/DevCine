# One named audio track of a video (MKV ingest). Every ingested video has at
# least one: non-MKV uploads get a single "default" row naming the audio that
# is embedded in the file; an MKV's tracks are stripped into one row each,
# named from the container's own metadata, first track = default (position 1,
# remuxed into the playable MP4). Alternate tracks carry their extracted audio
# as an attachment, ready for the future HLS audio-switching player.
class AudioTrack < ApplicationRecord
  belongs_to :video

  # The stripped audio (.m4a) for ALTERNATE tracks; the default track has no
  # file — its sound lives inside the video's own MP4.
  has_one_attached :file

  validates :name, presence: true
  validates :position, numericality: { only_integer: true, greater_than: 0 }

  scope :ordered, -> { order(:position) }

  def default?
    position == 1
  end
end
