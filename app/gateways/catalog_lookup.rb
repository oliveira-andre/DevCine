# Orchestrates the per-content-type gateway chains (admin catalog creation):
#
#   Movies:   TMDB (primary) → Fanart.tv (artwork fallback)
#   TV shows: TMDB (primary) → Fanart.tv (artwork) → TVmaze (full fallback)
#   Anime:    AniList (primary) → TMDB (fallback)
#
# Fanart.tv cannot search (artwork-only), so in the SEARCH chain it is skipped;
# it participates as the poster supplement when the winning source lacks one.
# Every method degrades gracefully: unconfigured/failed gateways just fall
# through, and an empty result is an empty list / nil — never an exception.
class CatalogLookup
  KINDS = %w[movie serie anime].freeze

  SEARCH_CHAINS = {
    "movie" => [ [ TmdbGateway, :search_movies ] ],
    "serie" => [ [ TmdbGateway, :search_tv ], [ TvmazeGateway, :search_shows ] ],
    "anime" => [ [ AnilistGateway, :search_anime ], [ TmdbGateway, :search_tv ] ]
  }.freeze

  DETAIL_METHODS = {
    [ "movie", "tmdb" ]    => :movie_details,
    [ "serie", "tmdb" ]    => :tv_details,
    [ "serie", "tvmaze" ]  => :show_details,
    [ "anime", "anilist" ] => :anime_details,
    [ "anime", "tmdb" ]    => :tv_details
  }.freeze

  DETAIL_GATEWAYS = {
    "tmdb" => TmdbGateway, "tvmaze" => TvmazeGateway, "anilist" => AnilistGateway
  }.freeze

  # First configured gateway in the chain that yields results wins.
  def self.search(kind, query)
    return [] if query.blank? || !KINDS.include?(kind.to_s)

    Array(SEARCH_CHAINS[kind.to_s]).each do |gateway_class, method|
      next unless gateway_class.configured? && gateway_class.searchable?

      results = gateway_class.new.public_send(method, query)
      return results if results.present?
    end
    []
  end

  # Normalized details for a picked search result; poster supplemented from
  # Fanart.tv when the source came back without one.
  def self.details(kind, source, external_id)
    gateway_class = DETAIL_GATEWAYS[source.to_s]
    method = DETAIL_METHODS[[ kind.to_s, source.to_s ]]
    return nil unless gateway_class && method && gateway_class.configured?

    details = gateway_class.new.public_send(method, external_id)
    return nil unless details

    if details[:poster_url].blank? && source.to_s == "tmdb" && FanartGateway.configured?
      fanart = FanartGateway.new
      details[:poster_url] =
        kind.to_s == "movie" ? fanart.movie_poster(external_id) : details[:poster_url]
    end
    details
  end
end
