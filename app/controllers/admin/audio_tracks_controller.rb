module Admin
  # Read-only audio-track manager modal (MKV ingest): what tracks a video
  # carries and a download for each stripped .m4a. Tracks are created by
  # VideoIngest, not by hand, so unlike the subtitle manager there is nothing
  # to add or edit here.
  class AudioTracksController < AdminController
    include ModalLayout

    def index
      @video = Video.friendly.find(params[:video_slug])
      @audio_tracks = @video.audio_tracks.ordered.with_attached_file
    end
  end
end
