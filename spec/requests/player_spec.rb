require 'rails_helper'

RSpec.describe "Player", type: :request do
  let(:member) { create(:user, password: "password123") }

  def sign_in(user = member)
    post session_path, params: { email_address: user.email_address, password: "password123" }
  end

  describe "live embeds (feature 009)" do
    it "renders the embed iframe with the stored URL as src" do
      sign_in
      live = create(:video, :live, visibility: :public, title: "Live Now")
      get player_path(live.slug)
      expect(response).to have_http_status(:ok)
      expect(response.body).to include(%(class="live-embed__frame"))
      expect(response.body).to include(%(src="#{live.live_embed_url}"))
      # A live is not fed to the persistent file player (feature 010).
      expect(response.body).not_to include('data-controller="player-source"')
    end

    it "shows the unavailable state for a live with no embed URL (no iframe)" do
      sign_in
      # bypass the validation to simulate a live whose URL was cleared
      live = create(:video, :live, visibility: :public)
      live.update_column(:live_embed_url, nil)
      get player_path(live.slug)
      expect(response.body).to include("not available yet")
      expect(response.body).not_to include("live-embed__frame")
    end
  end

  describe "GET /playing/:slug" do
    it "renders the player with the proxy media source for a public video" do
      sign_in
      video = create(:video, :with_file, visibility: :public)
      get player_path(video.slug)
      expect(response).to have_http_status(:ok)
      expect(response.body).to include("/rails/active_storage/blobs/proxy/")
      expect(response.body).to include(video.title)
    end

    it "plays an unlisted video via direct link" do
      sign_in
      video = create(:video, :with_file, visibility: :unlisted)
      get player_path(video.slug)
      expect(response).to have_http_status(:ok)
    end

    it "allows the owner to watch a private video" do
      owner = create(:user, password: "password123")
      video = create(:video, :with_file, visibility: :private, uploader: owner)
      sign_in(owner)
      get player_path(video.slug)
      expect(response).to have_http_status(:ok)
    end

    it "returns 404 for a private video requested by a non-owner" do
      sign_in
      video = create(:video, :with_file, visibility: :private, uploader: create(:user))
      get player_path(video.slug)
      expect(response).to have_http_status(:not_found)
    end

    it "returns 404 for an unknown slug" do
      sign_in
      get player_path("does-not-exist")
      expect(response).to have_http_status(:not_found)
    end

    it "shows a graceful message when the media file is missing" do
      sign_in
      video = create(:video, visibility: :public) # no :with_file
      get player_path(video.slug)
      expect(response).to have_http_status(:ok)
      expect(response.body).to include("not available")
    end

    it "requires authentication" do
      video = create(:video, :with_file, visibility: :public)
      get player_path(video.slug)
      expect(response).to redirect_to(new_session_path)
    end
  end
end
