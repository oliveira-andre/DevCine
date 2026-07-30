class SeriesController < ApplicationController
  include Paginatable
  include CatalogListing

  # Series (20/pg) — policy-scoped, genre-filtered and sorted (feature 011).
  def index
    scope = ordered(by_genre(policy_scope(Serie).with_attached_poster))
    @pagy, @series = paginate(scope, limit: 20)
  end

  # GET /series/:slug — the collection show page (feature 007). Renders the hero,
  # title + Play/Continue, seasons carousel, and the default season's episodes.
  def show
    @serie = policy_scope(Serie).with_attached_poster.friendly.find(params[:slug])
    @current_video = @serie.current_video(Current.user, pundit_user)
    @hero_video = @current_video || @serie.first_video(pundit_user)
    @play_target = @serie.play_target(Current.user, pundit_user)
    @season = default_season
    @pagy, @videos = paginate_season(@season)
    @next_url = @pagy&.next ? season_series_path(@serie, @season.position, page: @pagy.next) : nil
  end

  # GET /series/:slug/seasons/:position — the episodes Turbo Frame for one season
  # (season switch target + infinite-scroll page source).
  def season
    @serie = policy_scope(Serie).friendly.find(params[:slug])
    @season = @serie.seasons.find_by!(position: params[:position])
    @current_video = @serie.current_video(Current.user, pundit_user)
    @pagy, @videos = paginate_season(@season)
    @next_url = @pagy&.next ? season_series_path(@serie, @season.position, page: @pagy.next) : nil
    render :season
  end

  private

    # The season containing the viewer's current video, else the first season.
    def default_season
      seasons = @serie.ordered_seasons.to_a
      return seasons.first if @current_video.nil?

      seasons.find { |s| s.episodes.exists?(video_id: @current_video.id) } || seasons.first
    end

    # Paginate one season's visible episode videos in canonical order.
    def paginate_season(season)
      return [ nil, [] ] if season.nil?

      ids = @serie.season_video_ids(season, pundit_user)
      paginate(Video.in_order_of(:id, ids).with_attached_thumbnail, limit: 12)
    end
end
