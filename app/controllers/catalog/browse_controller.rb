class Catalog::BrowseController < ApplicationController
  include Paginatable

  # Category browse: a genre (movies + series tagged with it, 20/pg) or a video
  # kind (public videos of that kind, 50/pg).
  def show
    if params[:slug].present?
      @genre = Genre.friendly.find(params[:slug])
      @title = @genre.name
      combined = (@genre.movies.to_a + @genre.series.to_a).sort_by(&:created_at).reverse
      @pagy, @items = paginate(combined, limit: 20)
    else
      @kind = params[:kind]
      raise ActiveRecord::RecordNotFound unless Video.kinds.key?(@kind)

      @title = @kind.titleize
      @pagy, @items = paginate(
        Video.where(kind: @kind).listable.recent.with_attached_thumbnail, limit: 50
      )
    end
  end
end
