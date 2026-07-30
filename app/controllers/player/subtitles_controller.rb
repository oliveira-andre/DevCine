module Player
  # Serves a video's subtitle track as WebVTT for the <track> element (feature
  # 012). The track is authorized through the owning video, so restricted/hidden
  # videos never leak captions (FR-016).
  class SubtitlesController < ApplicationController
    include Playable

    def show
      video = find_playable_video!
      subtitle = video.subtitles.find(params[:id])
      render plain: subtitle.to_vtt, content_type: "text/vtt"
    end
  end
end
