module Admin
  # Admin subtitle management (feature 012): a searchable video list, each
  # linking to its per-video subtitle manager.
  class VideosController < AdminController
    include Paginatable

    def index
      @query = params[:q].to_s.strip
      scope = Video.where.not(kind: :live).recent
      scope = scope.where("videos.title ILIKE ?", "%#{Video.sanitize_sql_like(@query)}%") if @query.present?
      @pagy, @videos = paginate(scope.with_attached_thumbnail, limit: 20)
    end

    def show
      @video = Video.friendly.find(params[:slug])
      @subtitles = @video.subtitles.order(:language)
    end
  end
end
