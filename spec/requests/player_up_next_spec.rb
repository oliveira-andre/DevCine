require 'rails_helper'

# Feature 010 (US5): the autoplay descriptor endpoint. Precedence is
# serie-next → playlist-next → first "more like this" not already played; 204
# when nothing eligible remains; restricted-locked candidates are skipped.
RSpec.describe "Player up_next", type: :request do
  let(:member) { create(:user, password: "password123") }
  before { post session_path, params: { email_address: member.email_address, password: "password123" } }

  def body = JSON.parse(response.body)

  describe "serie next" do
    it "returns the next episode descriptor" do
      v1, v2 = create_list(:video, 2, :with_file, visibility: :public)
      serie = create(:serie)
      season = create(:season, serie: serie, position: 1)
      create(:episode, season: season, video: v1, position: 1)
      create(:episode, season: season, video: v2, position: 2)

      get up_next_player_path(v1.slug)
      expect(response).to have_http_status(:ok)
      expect(body["slug"]).to eq(v2.slug)
      expect(body["album"]).to eq(serie.title)
      expect(body["src"]).to include("/rails/active_storage")
      expect(body["upNextUrl"]).to eq(up_next_player_path(v2.slug))
    end

    it "returns 204 at the serie end once the only recommendation is played" do
      v1, v2 = create_list(:video, 2, :with_file, visibility: :public, kind: :episode)
      serie = create(:serie)
      season = create(:season, serie: serie, position: 1)
      create(:episode, season: season, video: v1, position: 1)
      create(:episode, season: season, video: v2, position: 2)

      # v2 is last in the serie; the only same-kind recommendation is v1, which is
      # already in the played chain → autoplay stops.
      get up_next_player_path(v2.slug, played: [ v1.slug, v2.slug ].join(","))
      expect(response).to have_http_status(:no_content)
    end
  end

  describe "playlist next" do
    it "returns the next playlist item and keeps the list context" do
      a, b = create_list(:video, 2, :with_file, visibility: :public)
      playlist = create(:playlist, user: member, visibility: :public)
      create(:playlist_item, playlist: playlist, video: a, position: 1)
      create(:playlist_item, playlist: playlist, video: b, position: 2)

      get up_next_player_path(a.slug, list: playlist.id)
      expect(body["slug"]).to eq(b.slug)
      expect(body["album"]).to eq(playlist.title)
      expect(body["list"]).to eq(playlist.id)
      expect(body["upNextUrl"]).to eq(up_next_player_path(b.slug, list: playlist.id))
    end
  end

  describe "recommendation fallback" do
    it "falls back to a same-kind related video and skips the played chain" do
      current = create(:video, :with_file, visibility: :public, kind: :standalone)
      seen    = create(:video, :with_file, visibility: :public, kind: :standalone)
      fresh   = create(:video, :with_file, visibility: :public, kind: :standalone)

      get up_next_player_path(current.slug, played: [ current.slug, seen.slug ].join(","))
      expect(response).to have_http_status(:ok)
      expect(body["slug"]).to eq(fresh.slug)
      expect(body["album"]).to eq("DevCine")
    end

    it "returns 204 when every candidate was already played" do
      current = create(:video, :with_file, visibility: :public, kind: :standalone)
      other   = create(:video, :with_file, visibility: :public, kind: :standalone)

      get up_next_player_path(current.slug, played: [ current.slug, other.slug ].join(","))
      expect(response).to have_http_status(:no_content)
    end

    it "skips a restricted candidate when the session is locked" do
      current = create(:video, :with_file, visibility: :public, kind: :standalone)
      create(:video, :with_file, visibility: :restricted, maturity_rating: :A18, kind: :standalone)

      get up_next_player_path(current.slug, played: current.slug)
      expect(response).to have_http_status(:no_content)
    end
  end

  it "404s for an unknown slug" do
    get up_next_player_path("nope")
    expect(response).to have_http_status(:not_found)
  end
end
