class LivesController < ApplicationController
  include Paginatable

  # Live-kind videos (50/pg) — policy-scoped.
  def index
    @pagy, @lives = paginate(
      policy_scope(Video).live.recent.with_attached_thumbnail,
      limit: 50
    )
  end
end
