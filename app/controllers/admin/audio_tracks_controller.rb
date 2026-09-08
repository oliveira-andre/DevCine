module Admin
  # Audio-track manager modal (MKV ingest), mirroring the subtitle manager:
  # #index lists the video's tracks (download per stripped file, edit,
  # confirmed remove) and carries the add form. The default track (position 1)
  # is special — its sound is embedded in the playable MP4 itself, so it can
  # be renamed but never removed, and new tracks always need an audio file.
  #
  # The HLS package bakes one rendition per track, so any change to the
  # renditions themselves (add / remove / file replace) discards the package
  # (playback falls back to progressive) and re-enqueues the packager.
  class AudioTracksController < AdminController
    include ModalLayout

    before_action :set_video
    before_action :set_audio_track, only: %i[edit update destroy]

    def index
      @audio_track = @video.audio_tracks.new
      @audio_tracks = tracks
    end

    def create
      @audio_track = @video.audio_tracks.new(audio_track_params)
      @audio_track.position = (@video.audio_tracks.maximum(:position) || 0) + 1
      @audio_track.errors.add(:file, "is required — upload the track's audio") if params.dig(:audio_track, :file).blank?

      if @audio_track.errors.empty? && @audio_track.save
        repackage_hls
        redirect_to admin_video_audio_tracks_path(@video)
      else
        @audio_tracks = tracks
        render :index, status: :unprocessable_entity
      end
    end

    def edit; end

    def update
      if @audio_track.update(audio_track_params)
        # A new file changes the packaged rendition; a rename only changes the
        # menu label (read live from the row) and needs no repackage.
        repackage_hls if params.dig(:audio_track, :file).present?
        redirect_to admin_video_audio_tracks_path(@video)
      else
        render :edit, status: :unprocessable_entity
      end
    end

    def destroy
      if @audio_track.default?
        head :unprocessable_entity
      else
        @audio_track.destroy
        repackage_hls
        render turbo_stream: turbo_stream.remove("admin_audio_track_#{@audio_track.id}")
      end
    end

    private

    def tracks
      @video.audio_tracks.ordered.with_attached_file
    end

    def set_video
      @video = Video.friendly.find(params[:video_slug])
    end

    def set_audio_track
      @audio_track = @video.audio_tracks.find(params[:id])
    end

    def audio_track_params
      params.require(:audio_track).permit(:name, :language, :file)
    end

    def repackage_hls
      HlsPackager.discard(@video)
      HlsPackageJob.perform_later(@video)
    end
  end
end
