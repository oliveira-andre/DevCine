require 'rails_helper'

RSpec.describe "Playlist additions", type: :request do
  let(:member) { create(:user, password: "password123") }
  let(:video) { create(:video, :with_file, visibility: :public) }

  before { post session_path, params: { email_address: member.email_address, password: "password123" } }

  describe "GET /playing/:slug/add-to-playlist" do
    it "renders the modal listing the user's playlists" do
      get add_to_playlist_path(video.slug)
      expect(response).to have_http_status(:ok)
      expect(response.body).to include(User::LIKED_PLAYLIST_TITLE)
    end
  end

  describe "POST toggle" do
    it "adds the video, then removes it on a second toggle" do
      playlist = member.playlists.create!(title: "Watch Later", visibility: :private)
      expect {
        post toggle_playlist_video_path(playlist_id: playlist.id, slug: video.slug), as: :turbo_stream
      }.to change { playlist.playlist_items.count }.by(1)

      expect {
        post toggle_playlist_video_path(playlist_id: playlist.id, slug: video.slug), as: :turbo_stream
      }.to change { playlist.playlist_items.count }.by(-1)
    end

    it "does not let a user add a private video they can't view (IDOR)" do
      playlist = member.playlists.create!(title: "Watch Later", visibility: :private)
      private_video = create(:video, :with_file, visibility: :private, uploader: create(:user))
      expect {
        post toggle_playlist_video_path(playlist_id: playlist.id, slug: private_video.slug), as: :turbo_stream
      }.not_to change { playlist.playlist_items.count }
      expect(response).to have_http_status(:not_found)
    end
  end
end
