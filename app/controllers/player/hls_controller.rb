module Player
  # Serves a video's HLS package (master/media playlists + fMP4 segments) from
  # the local Disk volume, behind the same visibility policy as watching the
  # video. Segments are small (~SEGMENT_SECONDS each), so requests are quick —
  # the class of long-streaming-response problems can't occur here.
  class HlsController < ApplicationController
    include Playable

    CONTENT_TYPES = {
      ".m3u8" => "application/vnd.apple.mpegurl",
      ".m4s" => "video/iso.segment",
      ".mp4" => "video/mp4"
    }.freeze

    def show
      video = find_playable_video!
      base = HlsPackager.dir_for(video)
      file = base.join(params[:rest].to_s).cleanpath

      # Traversal-proof: the resolved path must stay inside this video's dir,
      # and only package file types are served.
      type = CONTENT_TYPES[file.extname]
      raise ActiveRecord::RecordNotFound unless type && file.to_s.start_with?("#{base}/") && file.file?

      # Segments/init are content-addressed by the package build — cache hard.
      # Playlists are tiny; let them revalidate.
      expires_in(1.year, public: false) unless file.extname == ".m3u8"
      send_file file, type: type, disposition: "inline"
    end
  end
end
