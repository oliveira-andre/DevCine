class SeriesController < ApplicationController
  include Paginatable

  # Series (20/pg).
  def index
    @pagy, @series = paginate(Serie.recent.with_attached_poster, limit: 20)
  end
end
