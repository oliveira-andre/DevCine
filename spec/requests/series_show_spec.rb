require 'rails_helper'

RSpec.describe "Series show", type: :request do
  let(:member) { create(:user, password: "password123") }

  def sign_in(user = member)
    post session_path, params: { email_address: user.email_address, password: "password123" }
  end

  before { sign_in }

  def serie_with(*videos)
    serie = create(:serie)
    season = create(:season, serie: serie, position: 1)
    videos.each_with_index { |v, i| create(:episode, season: season, video: v, position: i + 1) }
    serie
  end

  describe "GET /series/:slug" do
    it "renders the title, episode cards, and a hero linking to the player" do
      v1 = create(:video, :with_thumbnail, title: "Pilot", visibility: :public)
      v2 = create(:video, :with_thumbnail, title: "Second", visibility: :public)
      serie = serie_with(v1, v2)

      get serie_path(serie)

      expect(response).to have_http_status(:ok)
      expect(response.body).to include(serie.title)
      expect(response.body).to include("Pilot").and include("Second")
      expect(response.body).to include(player_path(v1.slug))
    end

    it "hides a restricted episode while locked" do
      public_v = create(:video, :with_thumbnail, title: "Open", visibility: :public)
      gated = create(:video, :with_thumbnail, title: "Gated", visibility: :restricted, maturity_rating: :A18)
      serie = serie_with(public_v, gated)

      get serie_path(serie)

      expect(response.body).to include("Open")
      expect(response.body).not_to include(player_path(gated.slug))
    end

    it "404s for an all-restricted series while locked" do
      serie = serie_with(create(:video, visibility: :restricted, maturity_rating: :A18))
      get serie_path(serie)
      expect(response).to have_http_status(:not_found)
    end

    it "404s for an unknown slug" do
      get serie_path("does-not-exist")
      expect(response).to have_http_status(:not_found)
    end

    it "Play targets the first video with no history and reads 'Play'" do
      v1 = create(:video, :with_thumbnail, visibility: :public)
      v2 = create(:video, :with_thumbnail, visibility: :public)
      serie = serie_with(v1, v2)

      get serie_path(serie)

      expect(response.body).to include(">Play<")
      expect(response.body).to include(%(href="#{player_path(v1.slug)}"))
    end

    it "Continue targets the most-recently-watched video and reads 'Continue'" do
      v1 = create(:video, :with_thumbnail, visibility: :public)
      v2 = create(:video, :with_thumbnail, visibility: :public)
      serie = serie_with(v1, v2)
      VideoView.record!(member, v2)

      get serie_path(serie)

      expect(response.body).to include(">Continue<")
      # The Play button links to the resumed video (within the series sequence).
      expect(response.body).to match(%r{collection__play[^>]*href="#{Regexp.escape(player_path(v2.slug))}"})
    end

    it "omits the Play button for a series with no visible videos" do
      serie = create(:serie)
      create(:season, serie: serie, position: 1)
      get serie_path(serie)
      expect(response.body).not_to include("collection__play")
    end
  end

  describe "GET /series/:slug/seasons/:position" do
    it "returns the episodes frame for the requested season" do
      s1v = create(:video, :with_thumbnail, title: "S1 Ep", visibility: :public)
      s2v = create(:video, :with_thumbnail, title: "S2 Ep", visibility: :public)
      serie = create(:serie)
      season1 = create(:season, serie: serie, position: 1)
      season2 = create(:season, serie: serie, position: 2)
      create(:episode, season: season1, video: s1v, position: 1)
      create(:episode, season: season2, video: s2v, position: 1)

      get serie_season_path(serie, 2)

      expect(response).to have_http_status(:ok)
      expect(response.body).to include("S2 Ep")
      expect(response.body).not_to include("S1 Ep")
      expect(response.body).to include('id="episodes"')
    end

    it "404s for an unknown season position" do
      serie = serie_with(create(:video, visibility: :public))
      get serie_season_path(serie, 99)
      expect(response).to have_http_status(:not_found)
    end
  end
end
