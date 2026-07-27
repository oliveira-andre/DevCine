require 'rails_helper'

RSpec.describe "Playlists show", type: :request do
  let(:member) { create(:user, password: "password123") }
  let(:owner)  { create(:user, password: "password123") }

  def sign_in(user = member)
    post session_path, params: { email_address: user.email_address, password: "password123" }
  end

  def playlist_with(user:, visibility:, titles:)
    playlist = create(:playlist, user: user, visibility: visibility)
    titles.each_with_index do |t, i|
      video = create(:video, :with_thumbnail, title: t, visibility: :public)
      create(:playlist_item, playlist: playlist, video: video, position: i + 1)
    end
    playlist
  end

  describe "GET /playlists/:id" do
    it "renders a public playlist's title and ordered video cards for any viewer" do
      sign_in
      playlist = playlist_with(user: owner, visibility: :public, titles: %w[Alpha Bravo])

      get playlist_path(playlist)

      expect(response).to have_http_status(:ok)
      expect(response.body).to include(playlist.title)
      expect(response.body).to include("Alpha").and include("Bravo")
      first = playlist.videos.joins(:playlist_items).order("playlist_items.position").first
      expect(response.body).to include(player_path(first.slug))
    end

    it "renders an unlisted playlist for any viewer" do
      sign_in
      playlist = playlist_with(user: owner, visibility: :unlisted, titles: %w[Only])
      get playlist_path(playlist)
      expect(response).to have_http_status(:ok)
    end

    it "404s a private playlist for a non-owner but shows it to the owner" do
      private_list = playlist_with(user: owner, visibility: :private, titles: %w[Secret])

      sign_in(member)
      get playlist_path(private_list)
      expect(response).to have_http_status(:not_found)

      sign_in(owner)
      get playlist_path(private_list)
      expect(response).to have_http_status(:ok)
      expect(response.body).to include("Secret")
    end

    it "404s for an unknown id" do
      sign_in
      get playlist_path("00000000-0000-0000-0000-000000000000")
      expect(response).to have_http_status(:not_found)
    end
  end
end
