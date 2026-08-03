class SearchController < ApplicationController
  include CatalogListing

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
    # Sorted per feature 011 (the ordering pill applies to all three sections).
    @videos = ordered(policy_scope(Video).where("videos.title ILIKE ?", term))
                .with_attached_thumbnail.with_attached_preview.limit(VIDEO_LIMIT)
    @movies = ordered(policy_scope(Movie).where("movies.title ILIKE ?", term)).with_attached_poster
                .includes(video: :preview_attachment).limit(CATALOG_LIMIT)
    @series = ordered(policy_scope(Serie).where("series.title ILIKE ?", term))
                .with_attached_poster.limit(CATALOG_LIMIT)
    # Public playlists only (Playlist.discoverable): unlisted ones are reachable
    # by link but must never surface in a search.
    @playlists = ordered(Playlist.discoverable.where("playlists.title ILIKE ?", term))
                   .includes(:user, :playlist_items).limit(CATALOG_LIMIT)
  end
end
