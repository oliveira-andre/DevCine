require 'rails_helper'

# Gateway parsing specs: HTTP is stubbed at the get_json/post_json seam, so no
# network is touched — we verify each gateway normalizes provider payloads into
# the shared result/detail shapes.
RSpec.describe "Catalog gateways" do
  describe TmdbGateway do
    subject(:gateway) { described_class.new }

    it "is configured only with an API key" do
      allow(ENV).to receive(:[]).and_call_original
      allow(ENV).to receive(:[]).with("TMDB_API_KEY").and_return(nil)
      expect(described_class.configured?).to be(false)

      allow(ENV).to receive(:[]).with("TMDB_API_KEY").and_return("key123")
      expect(described_class.configured?).to be(true)
    end

    it "normalizes movie search results" do
      allow(gateway).to receive(:get_json).and_return(
        { results: [ { id: 27205, title: "Inception", overview: "Dreams.",
                       poster_path: "/p.jpg", release_date: "2010-07-15" } ] }
      )
      result = gateway.search_movies("inception").first
      expect(result).to include(source: "tmdb", external_id: "27205", kind: :movie,
                                title: "Inception", year: 2010)
      expect(result[:poster_url]).to eq("https://image.tmdb.org/t/p/w500/p.jpg")
    end

    it "builds tv details with seasons, skipping specials and fetching episode titles" do
      allow(gateway).to receive(:get_json).with("/3/tv/1396", anything).and_return(
        { id: 1396, name: "Breaking Bad", overview: "Chemistry.",
          poster_path: "/bb.jpg", backdrop_path: nil, first_air_date: "2008-01-20",
          in_production: false,
          seasons: [ { season_number: 0, name: "Specials", episode_count: 3 },
                     { season_number: 1, name: "Season 1", episode_count: 2 } ] }
      )
      allow(gateway).to receive(:get_json).with("/3/tv/1396/season/1", anything).and_return(
        { episodes: [ { episode_number: 1, name: "Pilot" }, { episode_number: 2, name: "Cat's in the Bag..." } ] }
      )

      details = gateway.tv_details(1396)
      expect(details[:title]).to eq("Breaking Bad")
      expect(details[:status]).to eq("ended")
      expect(details[:seasons].size).to eq(1) # specials skipped
      expect(details[:seasons].first[:episodes].map { |e| e[:title] }).to eq([ "Pilot", "Cat's in the Bag..." ])
    end

    it "falls back to numbered episode placeholders when the season fetch fails" do
      allow(gateway).to receive(:get_json).with("/3/tv/9", anything).and_return(
        { id: 9, name: "X", seasons: [ { season_number: 1, name: "S1", episode_count: 2 } ] }
      )
      allow(gateway).to receive(:get_json).with("/3/tv/9/season/1", anything).and_return(nil)

      episodes = gateway.tv_details(9)[:seasons].first[:episodes]
      expect(episodes).to eq([ { number: 1, title: nil }, { number: 2, title: nil } ])
    end
  end

  describe TvmazeGateway do
    subject(:gateway) { described_class.new }

    it "is keyless (always configured)" do
      expect(described_class.configured?).to be(true)
    end

    it "normalizes show search results and strips summary html" do
      allow(gateway).to receive(:get_json).and_return(
        [ { show: { id: 169, name: "Breaking Bad", premiered: "2008-01-20",
                    summary: "<p>A <b>teacher</b> turns to crime.</p>",
                    image: { medium: "m.jpg", original: "o.jpg" } } } ]
      )
      result = gateway.search_shows("breaking").first
      expect(result).to include(source: "tvmaze", external_id: "169", kind: :serie,
                                title: "Breaking Bad", year: 2008, poster_url: "o.jpg")
      expect(result[:overview]).to eq("A teacher turns to crime.")
    end

    it "groups embedded episodes into seasons" do
      allow(gateway).to receive(:get_json).and_return(
        { id: 169, name: "Breaking Bad", summary: "<p>Crime.</p>", premiered: "2008-01-20",
          status: "Ended", image: { original: "o.jpg" },
          _embedded: {
            seasons: [ { number: 1 }, { number: 2 } ],
            episodes: [ { season: 1, number: 1, name: "Pilot" },
                        { season: 2, number: 1, name: "Seven Thirty-Seven" } ]
          } }
      )
      details = gateway.show_details(169)
      expect(details[:status]).to eq("ended")
      expect(details[:seasons].map { |s| s[:number] }).to eq([ 1, 2 ])
      expect(details[:seasons].first[:episodes].first[:title]).to eq("Pilot")
    end
  end

  describe AnilistGateway do
    subject(:gateway) { described_class.new }

    it "prefers the english title and strips description html" do
      allow(gateway).to receive(:post_json).and_return(
        { data: { Page: { media: [ { id: 20, title: { romaji: "NARUTO", english: "Naruto" },
                                     description: "A ninja<br>story", coverImage: { large: "n.jpg" },
                                     startDate: { year: 2002 } } ] } } }
      )
      result = gateway.search_anime("naruto").first
      expect(result).to include(source: "anilist", external_id: "20", title: "Naruto", year: 2002)
      expect(result[:overview]).to eq("A ninja\nstory")
    end

    it "models anime details as one season of numbered episodes" do
      allow(gateway).to receive(:post_json).and_return(
        { data: { Media: { id: 20, title: { romaji: "NARUTO", english: "Naruto" },
                           description: "Ninja.", coverImage: { extraLarge: "xl.jpg" },
                           bannerImage: nil, startDate: { year: 2002, month: 10, day: 3 },
                           status: "FINISHED", episodes: 3 } } }
      )
      details = gateway.anime_details(20)
      expect(details[:status]).to eq("ended")
      expect(details[:release_date]).to eq(Date.new(2002, 10, 3))
      expect(details[:seasons]).to eq(
        [ { number: 1, name: "Season 1",
            episodes: [ { number: 1, title: nil }, { number: 2, title: nil }, { number: 3, title: nil } ] } ]
      )
    end
  end

  describe FanartGateway do
    it "cannot search (artwork-only)" do
      expect(described_class.searchable?).to be(false)
    end
  end

  describe CatalogLookup do
    it "falls through the serie chain to TVmaze when TMDB is unconfigured" do
      allow(TmdbGateway).to receive(:configured?).and_return(false)
      fake = instance_double(TvmazeGateway, search_shows: [ { title: "Breaking Bad" } ])
      allow(TvmazeGateway).to receive(:new).and_return(fake)

      expect(CatalogLookup.search("serie", "breaking").first[:title]).to eq("Breaking Bad")
    end

    it "falls through when the primary returns no results" do
      allow(TmdbGateway).to receive(:configured?).and_return(true)
      allow(TmdbGateway).to receive(:new).and_return(instance_double(TmdbGateway, search_tv: []))
      fake = instance_double(TvmazeGateway, search_shows: [ { title: "Found" } ])
      allow(TvmazeGateway).to receive(:new).and_return(fake)

      expect(CatalogLookup.search("serie", "x").first[:title]).to eq("Found")
    end

    it "routes anime to AniList first" do
      fake = instance_double(AnilistGateway, search_anime: [ { title: "Naruto" } ])
      allow(AnilistGateway).to receive(:new).and_return(fake)

      expect(CatalogLookup.search("anime", "naruto").first[:title]).to eq("Naruto")
    end

    it "routes details by (kind, source)" do
      fake = instance_double(TvmazeGateway, show_details: { title: "BB", poster_url: "x" })
      allow(TvmazeGateway).to receive(:new).and_return(fake)

      expect(CatalogLookup.details("serie", "tvmaze", 169)[:title]).to eq("BB")
    end

    it "supplements a missing tmdb movie poster from Fanart when configured" do
      allow(TmdbGateway).to receive(:configured?).and_return(true)
      allow(TmdbGateway).to receive(:new)
        .and_return(instance_double(TmdbGateway, movie_details: { title: "M", poster_url: nil }))
      allow(FanartGateway).to receive(:configured?).and_return(true)
      allow(FanartGateway).to receive(:new)
        .and_return(instance_double(FanartGateway, movie_poster: "fanart.jpg"))

      expect(CatalogLookup.details("movie", "tmdb", 1)[:poster_url]).to eq("fanart.jpg")
    end

    it "returns [] for a blank query or unknown kind" do
      expect(CatalogLookup.search("movie", "")).to eq([])
      expect(CatalogLookup.search("bogus", "x")).to eq([])
    end
  end
end
