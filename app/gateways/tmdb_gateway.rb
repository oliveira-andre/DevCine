# TMDB (themoviedb.org) — primary source for movies and TV shows, fallback for
# anime. Needs TMDB_API_KEY (a v3 API key). https://developer.themoviedb.org
class TmdbGateway < ApplicationGateway
  BASE_URL = "https://api.themoviedb.org".freeze
  IMAGE_BASE = "https://image.tmdb.org/t/p/w500".freeze
  MAX_SEASONS = 30 # cap the per-season episode fetches on huge shows

  def self.configured? = ENV["TMDB_API_KEY"].present?

  # --- search -----------------------------------------------------------------

  def search_movies(query)
    data = get_json("/3/search/movie", api_key:, query: query)
    Array(data&.dig(:results)).map { |r| search_result(r, :movie, r[:title], r[:release_date]) }
  end

  def search_tv(query)
    data = get_json("/3/search/tv", api_key:, query: query)
    Array(data&.dig(:results)).map { |r| search_result(r, :serie, r[:name], r[:first_air_date]) }
  end

  # --- details ----------------------------------------------------------------

  def movie_details(id)
    data = get_json("/3/movie/#{id}", api_key:)
    return nil unless data

    {
      source: "tmdb", external_id: data[:id].to_s, kind: :movie,
      title: data[:title], description: data[:overview].presence,
      poster_url: image_url(data[:poster_path]), backdrop_url: image_url(data[:backdrop_path]),
      release_date: safe_date(data[:release_date]), status: nil, seasons: []
    }
  end

  def tv_details(id)
    data = get_json("/3/tv/#{id}", api_key:)
    return nil unless data

    {
      source: "tmdb", external_id: data[:id].to_s, kind: :serie,
      title: data[:name], description: data[:overview].presence,
      poster_url: image_url(data[:poster_path]), backdrop_url: image_url(data[:backdrop_path]),
      release_date: safe_date(data[:first_air_date]),
      status: data[:in_production] ? "ongoing" : "ended",
      seasons: tv_seasons(data)
    }
  end

  private

  def api_key = ENV["TMDB_API_KEY"]

  def image_url(path)
    path.present? ? "#{IMAGE_BASE}#{path}" : nil
  end

  def search_result(row, kind, title, date)
    {
      source: "tmdb", external_id: row[:id].to_s, kind: kind,
      title: title, overview: row[:overview].presence,
      poster_url: image_url(row[:poster_path]), year: safe_date(date)&.year
    }
  end

  # Season 0 is "Specials" on TMDB — skipped. Episode titles need one request
  # per season, so cap it for pathological shows.
  def tv_seasons(data)
    Array(data[:seasons])
      .reject { |s| s[:season_number].to_i.zero? }
      .first(MAX_SEASONS)
      .map do |season|
        number = season[:season_number].to_i
        {
          number: number,
          name: season[:name].presence || "Season #{number}",
          episodes: season_episodes(data[:id], number, season[:episode_count].to_i)
        }
      end
  end

  def season_episodes(tv_id, number, episode_count)
    data = get_json("/3/tv/#{tv_id}/season/#{number}", api_key:)
    episodes = Array(data&.dig(:episodes)).map do |ep|
      { number: ep[:episode_number].to_i, title: ep[:name].presence }
    end
    return episodes if episodes.any?

    # Episode listing unavailable — fall back to numbered placeholders.
    (1..episode_count).map { |n| { number: n, title: nil } }
  end
end
