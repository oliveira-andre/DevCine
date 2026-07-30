# TVmaze — free, keyless TV database. Final fallback for TV shows: full search
# plus seasons and episode lists in a single embedded call. https://www.tvmaze.com/api
class TvmazeGateway < ApplicationGateway
  BASE_URL = "https://api.tvmaze.com".freeze

  def search_shows(query)
    data = get_json("/search/shows", q: query)
    Array(data).filter_map do |row|
      show = row[:show] or next
      {
        source: "tvmaze", external_id: show[:id].to_s, kind: :serie,
        title: show[:name], overview: strip_html(show.dig(:summary)),
        poster_url: show.dig(:image, :original) || show.dig(:image, :medium),
        year: safe_date(show[:premiered])&.year
      }
    end
  end

  def show_details(id)
    data = get_json("/shows/#{id}", "embed[]" => %w[seasons episodes])
    return nil unless data

    {
      source: "tvmaze", external_id: data[:id].to_s, kind: :serie,
      title: data[:name], description: strip_html(data[:summary]),
      poster_url: data.dig(:image, :original) || data.dig(:image, :medium),
      backdrop_url: nil,
      release_date: safe_date(data[:premiered]),
      status: data[:status].to_s.casecmp?("ended") ? "ended" : "ongoing",
      seasons: seasons_from(data)
    }
  end

  private

  # TVmaze embeds seasons and a flat episode list; group episodes per season.
  def seasons_from(data)
    episodes = Array(data.dig(:_embedded, :episodes)).group_by { |ep| ep[:season].to_i }
    seasons = Array(data.dig(:_embedded, :seasons))
    seasons = episodes.keys.sort.map { |n| { number: n } } if seasons.empty?

    seasons.map do |season|
      number = season[:number].to_i
      eps = Array(episodes[number]).map do |ep|
        { number: ep[:number].to_i, title: ep[:name].presence }
      end
      { number: number, name: "Season #{number}", episodes: eps }
    end
  end
end
