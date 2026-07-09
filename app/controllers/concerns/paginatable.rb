# Shared pagination for list controllers using pagy (43.6).
#
#   class MoviesController < ApplicationController
#     include Paginatable
#     def index
#       @pagy, @movies = paginate(Movie.recent, limit: 20)
#     end
#   end
#
# A page past the last one returns an empty result with a normal 200 (pagy 43.6
# does not raise for out-of-range offset pages), satisfying graceful overflow
# (FR-021).
module Paginatable
  extend ActiveSupport::Concern
  include Pagy::Method

  private

  def paginate(scope, limit: Pagy::OPTIONS[:limit])
    pagy(:offset, scope, limit: limit)
  end
end
