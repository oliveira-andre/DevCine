class VideosController < ApplicationController
  include Paginatable

  # Public standalone videos (50/pg).
  def index
    @pagy, @videos = paginate(
      Video.standalone.listable.recent.with_attached_thumbnail.with_attached_preview,
      limit: 50
    )
  end
end
