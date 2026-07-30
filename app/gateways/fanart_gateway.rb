# Fanart.tv — artwork-only fallback (it cannot search by name; lookups are by
# TMDB id for movies and TheTVDB id for shows). Used to supplement a missing
# poster. Needs FANART_API_KEY. https://fanart.tv/api-docs/
class FanartGateway < ApplicationGateway
  BASE_URL = "https://webservice.fanart.tv".freeze

  def self.configured? = ENV["FANART_API_KEY"].present?
  def self.searchable? = false

  # Best movie poster for a TMDB movie id, or nil.
  def movie_poster(tmdb_id)
    data = get_json("/v3/movies/#{tmdb_id}", api_key:)
    first_url(data, :movieposter)
  end

  # Best show poster for a TheTVDB id, or nil.
  def tv_poster(tvdb_id)
    data = get_json("/v3/tv/#{tvdb_id}", api_key:)
    first_url(data, :tvposter)
  end

  private

  def api_key = ENV["FANART_API_KEY"]

  def first_url(data, key)
    Array(data&.dig(key)).first&.dig(:url).presence
  end
end
