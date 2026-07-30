require 'rails_helper'

# Feature 007: inside a collection, the player wires prev/next to the real
# neighbors and orders "More like this" by the sequence.
RSpec.describe "Player sequence navigation", type: :request do
  let(:member) { create(:user, password: "password123") }
  before { post session_path, params: { email_address: member.email_address, password: "password123" } }

  # Serie: S1 = [e1, e2, e3], S2 = [e4]. Canonical order e1..e4.
  let(:serie) { create(:serie) }
  let(:videos) { create_list(:video, 4, :with_thumbnail, :with_file, visibility: :public) }
  let(:e1) { videos[0] }
  let(:e2) { videos[1] }
  let(:e3) { videos[2] }
  let(:e4) { videos[3] }

  before do
    s1 = create(:season, serie: serie, position: 1)
    s2 = create(:season, serie: serie, position: 2)
    create(:episode, season: s1, video: e1, position: 1)
    create(:episode, season: s1, video: e2, position: 2)
    create(:episode, season: s1, video: e3, position: 3)
    create(:episode, season: s2, video: e4, position: 1)
  end

  # feature 010: prev/next moved onto the player-source descriptor element.
  def prev_url(body) = body[/data-player-source-prev-url-value="([^"]*)"/, 1]
  def next_url(body) = body[/data-player-source-next-url-value="([^"]*)"/, 1]

  # A series is auto-derived from the episode, so neighbor links carry NO param.
  describe "prev/next neighbors (series auto-derived, no param)" do
    it "first episode: no prev, next is e2" do
      get player_path(e1.slug)
      expect(prev_url(response.body)).to eq("")
      expect(next_url(response.body)).to eq(player_path(e2.slug))
    end

    it "middle episode: prev e1, next e3" do
      get player_path(e2.slug)
      expect(prev_url(response.body)).to eq(player_path(e1.slug))
      expect(next_url(response.body)).to eq(player_path(e3.slug))
    end

    it "last of season 1 rolls into first of season 2" do
      get player_path(e3.slug)
      expect(next_url(response.body)).to eq(player_path(e4.slug))
    end

    it "last episode overall: prev e3, no next" do
      get player_path(e4.slug)
      expect(prev_url(response.body)).to eq(player_path(e3.slug))
      expect(next_url(response.body)).to eq("")
    end
  end

  describe "ordered related sidebar" do
    it "lists the sequence in order under 'Episodes'" do
      get related_player_path(e1.slug)
      expect(response.body).to include("Episodes")
      body = response.body
      expect(body.index(e2.title)).to be < body.index(e3.title)
      expect(body.index(e3.title)).to be < body.index(e4.title)
    end

    it "sidebar links break out of the frame to _top (not a frame swap)" do
      get related_player_path(e1.slug)
      expect(response.body).to match(/related__item[^>]*data-turbo-frame="_top"/)
    end
  end

  describe "standalone video (no sequence)" do
    it "has no prev/next and falls back to same-kind related" do
      solo = create(:video, :with_thumbnail, :with_file, visibility: :public, kind: :standalone)
      get player_path(solo.slug)
      expect(prev_url(response.body)).to eq("")
      expect(next_url(response.body)).to eq("")

      get related_player_path(solo.slug)
      expect(response.body).to include("More like this")
    end
  end

  describe "playlist context (?list=)" do
    it "wires neighbors by playlist position" do
      playlist = create(:playlist, user: member, visibility: :public)
      a = create(:video, :with_thumbnail, :with_file, visibility: :public)
      b = create(:video, :with_thumbnail, :with_file, visibility: :public)
      create(:playlist_item, playlist: playlist, video: a, position: 1)
      create(:playlist_item, playlist: playlist, video: b, position: 2)

      get player_path(a.slug, list: playlist.id)
      expect(next_url(response.body)).to eq(player_path(b.slug, list: playlist.id))
    end
  end
end
