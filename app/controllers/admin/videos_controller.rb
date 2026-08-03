module Admin
  # Full video management (feature 013): a searchable, filterable list of every
  # non-live video (standalone uploads + catalog videos), a detail page (with
  # the per-video subtitle manager), metadata edit, and delete. Lives are
  # managed separately under Admin::LivesController.
  class VideosController < AdminController
    include Paginatable
    include ModalLayout

    PAGE_LIMIT = 20

    before_action :set_video, only: %i[show edit update destroy]

    def index
      @query = params[:q].to_s.strip
      @pagy, @videos = paginate(filtered_scope, limit: PAGE_LIMIT)
    end

    def show
      @subtitles = @video.subtitles.order(:language)
      @comments_count = @video.comments.count
    end

    def edit; end

    def update
      if @video.update(video_params)
        render turbo_stream: [
          turbo_stream.replace("admin_video_row_#{@video.id}",
                               partial: "admin/videos/row", locals: { item: @video }),
          turbo_stream.replace("admin_video_detail",
                               partial: "admin/videos/detail", locals: { video: @video }),
          turbo_stream.update("modal", "")
        ]
      else
        render :edit, status: :unprocessable_entity
      end
    end

    def destroy
      @video.destroy
      if params[:back_to_index]
        flash[:_full_render] = true
        redirect_to admin_videos_path, notice: "Video deleted.", status: :see_other
      else
        render turbo_stream: turbo_stream.remove("admin_video_row_#{@video.id}")
      end
    end

    private

      def set_video
        @video = Video.friendly.find(params[:slug])
      end

      def filtered_scope
        scope = Video.where.not(kind: :live).recent.with_attached_thumbnail.includes(:uploader)
        scope = scope.where("videos.title ILIKE ?", "%#{Video.sanitize_sql_like(@query)}%") if @query.present?
        scope = scope.where(kind: params[:kind]) if valid_enum?(Video.kinds, params[:kind])
        scope = scope.where(visibility: params[:visibility]) if valid_enum?(Video.visibilities, params[:visibility])
        scope = scope.where(status: params[:status]) if valid_enum?(Video.statuses, params[:status])
        scope
      end

      def valid_enum?(enum, value)
        value.present? && enum.key?(value)
      end

      def video_params
        params.require(:video).permit(:title, :description, :maturity_rating, :visibility)
      end
  end
end
