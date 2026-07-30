class Catalog::BrowseController < ApplicationController
  include Paginatable
  include CatalogListing

  # Category browse: a genre (movies + series tagged with it, 20/pg) or a video
  # kind (public videos of that kind, 50/pg). Sorted per feature 011.
  def show
    if params[:slug].present?
      @genre = Genre.friendly.find(params[:slug])
      @title = @genre.name
      # Two models, one shelf: combined in memory (catalog-scale), policy-scoped,
      # with posters + videos eager-loaded so the page renders without N+1s.
      movies = policy_scope(@genre.movies).includes(:poster_attachment, video: :preview_attachment).to_a
      series = policy_scope(@genre.series).includes(:poster_attachment).to_a
      @pagy, @items = paginate(ordered_array(movies + series), limit: 20)
    else
      @kind = params[:kind]
      raise ActiveRecord::RecordNotFound unless Video.kinds.key?(@kind)

      @title = @kind.titleize
      scope = ordered(policy_scope(Video).where(kind: @kind).with_attached_thumbnail)
      @pagy, @items = paginate(scope, limit: 50)
    end
  end
end
