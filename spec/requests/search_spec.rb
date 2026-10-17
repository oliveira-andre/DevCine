require 'rails_helper'

RSpec.describe "Search", type: :request do
  before do
    user = create(:user, password: "password123")
    post session_path, params: { email_address: user.email_address, password: "password123" }
  end

  describe "GET /search" do
    it "renders every genre and video-kind category" do
      %w[Action Drama Gaming].each { |name| Genre.create!(name: name) }

      get search_path
      expect(response).to have_http_status(:ok)

      %w[Action Drama Gaming].each { |name| expect(response.body).to include(name) }
      Video.kinds.each_key { |kind| expect(response.body).to include(kind.titleize) }
    end
  end

  describe "GET /search?q=" do
    def card_titles = response.parsed_body.css(".poster-card__title").map(&:text)

    it "finds videos by their own, serie or movie title, and lists what they belong to" do
      create(:video, title: "Galaxy Warriors", visibility: :public)
      episode_video = create(:video, title: "Rangers S1E1", visibility: :public)
      serie = Serie.create!(title: "Galaxy Rangers")
      create(:episode, season: create(:season, serie: serie), video: episode_video)
      create(:movie, title: "Galaxy Quest", video: create(:video, title: "Feature Cut", visibility: :public))
      create(:video, title: "Unrelated Clip", visibility: :public)

      get search_path(q: "galaxy")

      expect(card_titles).to contain_exactly(
        "Galaxy Warriors", "Rangers S1E1", "Feature Cut", # Videos
        "Galaxy Quest",                                   # Movies (via Feature Cut)
        "Galaxy Rangers"                                  # Series (via Rangers S1E1)
      )
    end

    it "lists matched movies, then series, then videos" do
      episode_video = create(:video, title: "Rangers S1E1", visibility: :public)
      create(:episode, season: create(:season, serie: Serie.create!(title: "Galaxy Rangers")), video: episode_video)
      create(:movie, title: "Galaxy Quest", video: create(:video, title: "Feature Cut", visibility: :public))

      get search_path(q: "galaxy")

      expect(response.parsed_body.css(".search-page__heading").map(&:text)).to eq(%w[Movies Series Videos])
    end

    it "shows only the sections that have matches" do
      create(:video, title: "Galaxy Warriors", visibility: :public)

      get search_path(q: "galaxy")

      expect(response.parsed_body.css(".search-page__heading").map(&:text)).to eq(%w[Videos])
    end

    it "does not list a serie with no matching videos" do
      Serie.create!(title: "Galaxy Rangers")

      get search_path(q: "galaxy")
      expect(response.body).to include("No results for")
    end

    it "tolerates typos" do
      create(:video, title: "Galaxy Warriors", visibility: :public)

      get search_path(q: "galxy warriors")
      expect(card_titles).to eq([ "Galaxy Warriors" ])
    end

    it "keeps the best matches and shows them in the ordering pill's order" do
      stub_const("SearchController::VIDEO_LIMIT", 2)
      create(:video, title: "Galaxy Warriors", visibility: :public, created_at: 3.days.ago)
      create(:video, title: "Galaxy Warrior A", visibility: :public, created_at: 2.days.ago)
      create(:video, title: "Galaxy Warrior B", visibility: :public, created_at: 1.day.ago)

      get search_path(q: "galaxy warriors")

      # The exact match is the oldest, so "most recent" alone would drop it.
      expect(card_titles.size).to eq(2)
      expect(card_titles.last).to eq("Galaxy Warriors")
    end

    it "excludes private videos from results" do
      create(:video, title: "Galaxy Secret", visibility: :private, uploader: create(:user))
      get search_path(q: "galaxy")
      expect(response.body).not_to include("Galaxy Secret")
    end

    it "shows an empty state when nothing matches" do
      get search_path(q: "zzzz-no-match")
      expect(response.body).to include("No results for")
    end

    it "treats SQL LIKE wildcards literally" do
      create(:video, title: "Percent Test", visibility: :public)
      get search_path(q: "%")
      expect(response.body).to include("No results for")
    end
  end
end
