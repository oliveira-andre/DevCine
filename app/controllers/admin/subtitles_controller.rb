module Admin
  # Attach/replace/remove SRT subtitle tracks for a video (feature 012, US4).
  # #new doubles as the per-video subtitle MANAGER modal: existing tracks
  # (filename + edit + confirmed remove) plus the add form with an SRT dropzone.
  class SubtitlesController < AdminController
    include ModalLayout

    before_action :set_video
    before_action :set_subtitle, only: %i[edit update destroy]

    def new
      @subtitle = @video.subtitles.new
      @subtitles = tracks
    end

    def edit; end

    def create
      @subtitle = @video.subtitles.new(subtitle_params)
      if @subtitle.save
        # Refresh the manager modal (the form lives in the modal frame, so the
        # redirect is followed in-frame) — the new track shows with its filename.
        redirect_to new_admin_video_subtitle_path(@video)
      else
        @subtitles = tracks
        render :new, status: :unprocessable_entity
      end
    end

    def update
      if @subtitle.update(subtitle_params)
        redirect_to new_admin_video_subtitle_path(@video)
      else
        render :edit, status: :unprocessable_entity
      end
    end

    def destroy
      @subtitle.destroy
      render turbo_stream: turbo_stream.remove("admin_subtitle_row_#{@subtitle.id}")
    end

    private

    def tracks
      @video.subtitles.order(:language).with_attached_file
    end

    def set_video
      @video = Video.friendly.find(params[:video_slug])
    end

    def set_subtitle
      @subtitle = @video.subtitles.find(params[:id])
    end

    def subtitle_params
      params.require(:subtitle).permit(:file, :language, :is_default)
    end
  end
end
