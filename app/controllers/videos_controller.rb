class VideosController < ApplicationController
  include Paginatable
  include ModalLayout

  # Public standalone videos (50/pg).
  def index
    @pagy, @videos = paginate(
      Video.standalone.listable.recent.with_attached_thumbnail.with_attached_preview,
      limit: 50
    )
  end

  # Standalone video upload form, rendered in the shared modal (US5).
  def new
    @video = Current.user.uploaded_videos.new
  end

  def create
    @video = Current.user.uploaded_videos.new(video_params)
    @video.kind = :standalone   # forced server-side
    @video.status = :ready
    @video.require_file = true

    if @video.save
      render turbo_stream: [
        turbo_stream.update("modal", ""),
        turbo_stream.prepend("recent_uploads_items", partial: "home/poster_card", locals: { item: @video })
      ]
    else
      render :new, status: :unprocessable_entity
    end
  end

  private

  def video_params
    params.require(:video).permit(:title, :description, :maturity_rating, :visibility, :file, :thumbnail)
  end
end
