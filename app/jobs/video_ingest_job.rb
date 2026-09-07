# Runs the MKV ingest off the request path: remuxing a multi-GB file is
# disk-bound work far beyond a request budget. Until it finishes the video
# plays exactly as uploaded (an MKV may not play yet — same as before this
# feature existed). Best-effort by design: VideoIngest never raises.
class VideoIngestJob < ApplicationJob
  queue_as :default

  def perform(video)
    result = VideoIngest.call(video)
    if result.ok?
      # Tracks exist now — build the segmented HLS package next.
      HlsPackageJob.perform_later(video)
    else
      Rails.logger.warn("VideoIngestJob: #{video.id} — #{result.error}")
    end
  end
end
