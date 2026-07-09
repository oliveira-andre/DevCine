class MoviesController < ApplicationController
  include Paginatable

  # Paginated movie grid (20/pg) with lazy Turbo-Frame append.
  def index
    @pagy, @movies = paginate(Movie.recent.with_attached_poster, limit: 20)
  end
end
