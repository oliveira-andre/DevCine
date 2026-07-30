class LivesController < ApplicationController
  include Paginatable
  include CatalogListing

  # Live-kind videos (50/pg) — policy-scoped, sorted per feature 011.
  def index
    scope = ordered(policy_scope(Video).live.with_attached_thumbnail)
    @pagy, @lives = paginate(scope, limit: 50)
  end
end
