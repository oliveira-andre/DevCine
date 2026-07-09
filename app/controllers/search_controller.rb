class SearchController < ApplicationController
  # Dedicated search entry page: a focused input + browsable categories.
  # Full-text results are out of scope for this feature.
  def index
    @genres = Genre.order(:name)
    @kinds = Video.kinds.keys
    @query = params[:q]
  end
end
