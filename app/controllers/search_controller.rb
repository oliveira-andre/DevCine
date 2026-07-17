class SearchController < ApplicationController
  VIDEO_LIMIT = 24
  CATALOG_LIMIT = 12

  # Search entry page: a focused input + browsable categories. With a query it
  # also returns title matches across videos, movies, and series (2026-07 fix —
  # previously the input collected `q` and did nothing with it).
  def index
    @genres = Genre.order(:name)
    @kinds = Video.kinds.keys
    @query = params[:q].to_s.strip

    return if @query.blank?

    term = "%#{Video.sanitize_sql_like(@query)}%"
    # Policy-scoped (006): restricted titles are searchable by name only while
    # the session is PIN-unlocked (FR-008).
    @videos = policy_scope(Video).where("videos.title ILIKE ?", term).recent
                                 .with_attached_thumbnail.with_attached_preview.limit(VIDEO_LIMIT)
    @movies = policy_scope(Movie).where("movies.title ILIKE ?", term).recent.with_attached_poster
                                 .includes(video: :preview_attachment).limit(CATALOG_LIMIT)
    @series = policy_scope(Serie).where("series.title ILIKE ?", term).recent
                                 .with_attached_poster.limit(CATALOG_LIMIT)
  end
end
