# Builds a video's HLS package off the request path (disk-bound `-c copy`
# segmentation). Chained after VideoIngestJob for new uploads; the videos:hls
# task backfills. Best-effort: a failure just leaves progressive playback.
class HlsPackageJob < ApplicationJob
  queue_as :default

  def perform(video)
    result = HlsPackager.call(video)
    return if result.ok?

    Rails.logger.warn("HlsPackageJob: #{video.id} — #{result.error}")
  end
end
