class LivesController < ApplicationController
  include Paginatable

  # Public live-kind videos (50/pg).
  def index
    @pagy, @lives = paginate(
      Video.live.listable.recent.with_attached_thumbnail,
      limit: 50
    )
  end
end
