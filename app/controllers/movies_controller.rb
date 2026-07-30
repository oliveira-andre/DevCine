class MoviesController < ApplicationController
  include Paginatable
  include CatalogListing

  # Paginated movie grid (20/pg) with lazy Turbo-Frame append, genre-filtered
  # and sorted per feature 011.
  def index
    scope = ordered(by_genre(policy_scope(Movie).with_attached_poster.includes(video: :preview_attachment)))
    @pagy, @movies = paginate(scope, limit: 20)
  end
end
