class SearchController < ApplicationController
  include CatalogListing

  VIDEO_LIMIT = 24
  CATALOG_LIMIT = 12

  # Search entry page: a focused input + browsable categories. With a query it
  # fuzzy-matches videos by their own title or the title of the serie or movie
  # they belong to (Video.search), and lists what those matched videos belong to
  # in the other sections. Playlists also match on their own title.
  def index
    @genres = Genre.order(:name)
    @kinds = Video.kinds.keys
    @query = params[:q].to_s.strip

    return if @query.blank?

    # Policy-scoped (006): restricted titles are searchable by name only while
    # the session is PIN-unlocked (FR-008).
    matches = policy_scope(Video).search(@query)
    matched_ids = matches.unscope(:order).select(:id)

    # The VIDEO_LIMIT best matches, shown in the ordering pill's order (feature
    # 011 — the pill applies to every section).
    @videos = ordered(Video.where(id: matches.limit(VIDEO_LIMIT).select(:id)))
                .with_attached_thumbnail.with_attached_preview
    @movies = ordered(policy_scope(Movie).where(video_id: matched_ids)).with_attached_poster
                .includes(video: :preview_attachment).limit(CATALOG_LIMIT)
    @series = ordered(policy_scope(Serie).where(id: Season.joins(:episodes)
                                                          .where(episodes: { video_id: matched_ids })
                                                          .select(:serie_id)))
                .with_attached_poster.limit(CATALOG_LIMIT)
    # Public playlists only (Playlist.discoverable): unlisted ones are reachable
    # by link but must never surface in a search. Found by their own title, or
    # by holding a matched video.
    holding_matches = PlaylistItem.where(video_id: matched_ids).select(:playlist_id)
    @playlists = ordered(Playlist.discoverable.search(@query)
                           .or(Playlist.discoverable.where(id: holding_matches)))
                   .includes(:user, :playlist_items).limit(CATALOG_LIMIT)
  end
end
