require 'rails_helper'

# The descriptor for the sequence's PREVIOUS video, used by the prev control to
# swap in place while fullscreen. Sequence only (serie / playlist) — unlike
# up_next there is no recommendation fallback; 204 when nothing playable.
RSpec.describe "Player previous", type: :request do
  let(:member) { create(:user, password: "password123") }
  before { post session_path, params: { email_address: member.email_address, password: "password123" } }

  def body = JSON.parse(response.body)

  def serie_with(*videos)
    serie = create(:serie)
    season = create(:season, serie: serie, position: 1)
    videos.each_with_index { |v, i| create(:episode, season: season, video: v, position: i + 1) }
    serie
  end

  it "returns the previous episode descriptor" do
    v1, v2 = create_list(:video, 2, :with_file, visibility: :public)
    serie = serie_with(v1, v2)

    get previous_player_path(v2.slug)
    expect(response).to have_http_status(:ok)
    expect(body["slug"]).to eq(v1.slug)
    expect(body["album"]).to eq(serie.title)
    expect(body["nextUrl"]).to eq(player_path(v2.slug))
    # Chained presses keep working: the descriptor carries its own prev hop.
    expect(body["prevDescriptorUrl"]).to eq(previous_player_path(v1.slug))
    expect(body["upNextUrl"]).to eq(up_next_player_path(v1.slug))
  end

  it "keeps the playlist context" do
    a, b = create_list(:video, 2, :with_file, visibility: :public)
    playlist = create(:playlist, user: member, visibility: :public)
    create(:playlist_item, playlist: playlist, video: a, position: 1)
    create(:playlist_item, playlist: playlist, video: b, position: 2)

    get previous_player_path(b.slug, list: playlist.id)
    expect(body["slug"]).to eq(a.slug)
    expect(body["list"]).to eq(playlist.id)
    expect(body["prevDescriptorUrl"]).to eq(previous_player_path(a.slug, list: playlist.id))
  end

  it "returns 204 on the first episode" do
    v1, v2 = create_list(:video, 2, :with_file, visibility: :public)
    serie_with(v1, v2)

    get previous_player_path(v1.slug)
    expect(response).to have_http_status(:no_content)
  end

  it "returns 204 when the previous episode has no playable file" do
    v1 = create(:video, visibility: :public)
    v2 = create(:video, :with_file, visibility: :public)
    serie_with(v1, v2)

    get previous_player_path(v2.slug)
    expect(response).to have_http_status(:no_content)
  end

  it "returns 204 for a standalone video (no recommendation fallback)" do
    current = create(:video, :with_file, visibility: :public, kind: :standalone)
    create(:video, :with_file, visibility: :public, kind: :standalone)

    get previous_player_path(current.slug)
    expect(response).to have_http_status(:no_content)
  end

  it "404s for an unknown slug" do
    get previous_player_path("nope")
    expect(response).to have_http_status(:not_found)
  end
end
