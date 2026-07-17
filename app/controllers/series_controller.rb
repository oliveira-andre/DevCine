class SeriesController < ApplicationController
  include Paginatable

  # Series (20/pg) — policy-scoped (all-restricted series hidden while locked).
  def index
    @pagy, @series = paginate(policy_scope(Serie).recent.with_attached_poster, limit: 20)
  end
end
