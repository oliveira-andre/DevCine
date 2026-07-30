# AniList — free, keyless GraphQL API; primary source for anime.
# https://docs.anilist.co  (POST https://graphql.anilist.co)
class AnilistGateway < ApplicationGateway
  BASE_URL = "https://graphql.anilist.co".freeze

  SEARCH_QUERY = <<~GRAPHQL.freeze
    query ($search: String) {
      Page(perPage: 10) {
        media(search: $search, type: ANIME) {
          id
          title { romaji english }
          description
          coverImage { large }
          startDate { year }
        }
      }
    }
  GRAPHQL

  DETAILS_QUERY = <<~GRAPHQL.freeze
    query ($id: Int) {
      Media(id: $id, type: ANIME) {
        id
        title { romaji english }
        description
        coverImage { extraLarge large }
        bannerImage
        startDate { year month day }
        status
        episodes
      }
    }
  GRAPHQL

  def search_anime(query)
    data = post_json("/", query: SEARCH_QUERY, variables: { search: query })
    Array(data&.dig(:data, :Page, :media)).map do |media|
      {
        source: "anilist", external_id: media[:id].to_s, kind: :serie,
        title: title_of(media), overview: strip_html(media[:description]),
        poster_url: media.dig(:coverImage, :large),
        year: media.dig(:startDate, :year)
      }
    end
  end

  def anime_details(id)
    data = post_json("/", query: DETAILS_QUERY, variables: { id: id.to_i })
    media = data&.dig(:data, :Media)
    return nil unless media

    episode_count = media[:episodes].to_i
    {
      source: "anilist", external_id: media[:id].to_s, kind: :serie,
      title: title_of(media), description: strip_html(media[:description]),
      poster_url: media.dig(:coverImage, :extraLarge) || media.dig(:coverImage, :large),
      backdrop_url: media[:bannerImage].presence,
      release_date: start_date(media),
      status: media[:status].to_s.casecmp?("RELEASING") ? "ongoing" : "ended",
      # AniList doesn't model TV-style seasons: one season, N numbered episodes.
      seasons: [ {
        number: 1, name: "Season 1",
        episodes: (1..[ episode_count, 1 ].max).map { |n| { number: n, title: nil } }
      } ]
    }
  end

  private

  def title_of(media)
    media.dig(:title, :english).presence || media.dig(:title, :romaji)
  end

  def start_date(media)
    date = media[:startDate]
    return nil unless date && date[:year]

    Date.new(date[:year], date[:month] || 1, date[:day] || 1)
  rescue Date::Error
    nil
  end
end
