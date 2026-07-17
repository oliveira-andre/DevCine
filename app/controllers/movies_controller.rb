class MoviesController < ApplicationController
  include Paginatable

  # Paginated movie grid (20/pg) with lazy Turbo-Frame append.
  def index
    @pagy, @movies = paginate(
      policy_scope(Movie).recent.with_attached_poster.includes(video: :preview_attachment), limit: 20
    )
  end
end
