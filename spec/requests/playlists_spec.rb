require 'rails_helper'

RSpec.describe "Playlists create", type: :request do
  let(:member) { create(:user, password: "password123") }
  before { post session_path, params: { email_address: member.email_address, password: "password123" } }

  describe "POST /playlists (account context, no slug)" do
    it "creates a public playlist owned by the current user" do
      expect {
        post playlists_path, params: { playlist: { title: "Road Trip" } }
      }.to change(member.playlists, :count).by(1)

      playlist = member.playlists.order(:created_at).last
      expect(playlist.title).to eq("Road Trip")
      expect(playlist.visibility).to eq("public")
    end

    it "always attaches to the current user even if a foreign user_id is posted" do
      other = create(:user)
      post playlists_path, params: { playlist: { title: "Mine", user_id: other.id } }
      expect(member.playlists.find_by(title: "Mine")).to be_present
      expect(other.playlists.find_by(title: "Mine")).to be_nil
    end

    it "appends a playlist card and closes the modal on success" do
      post playlists_path, params: { playlist: { title: "Chill" } },
           headers: { "Accept" => "text/vnd.turbo-stream.html" }
      expect(response.media_type).to eq("text/vnd.turbo-stream.html")
      expect(response.body).to include('action="append" target="account_playlists"')
      expect(response.body).to include('action="update" target="modal"')
      expect(response.body).to include("Chill")
    end

    it "rejects a blank title (422) and creates nothing" do
      expect {
        post playlists_path, params: { playlist: { title: "  " } },
             headers: { "Accept" => "text/vnd.turbo-stream.html, text/html" }
      }.not_to change(member.playlists, :count)
      expect(response).to have_http_status(:unprocessable_content)
      expect(response.body).to include("form-flash-alert") # validation error shown
    end
  end

  describe "DELETE /playlists/:id" do
    it "deletes the owner's playlist and removes it from both surfaces" do
      playlist = create(:playlist, user: member, title: "Temp")
      delete playlist_path(playlist), headers: { "Accept" => "text/vnd.turbo-stream.html" }

      expect(Playlist.exists?(playlist.id)).to be(false)
      expect(response.body).to include(%(target="playlist_row_#{playlist.id}"))
      expect(response.body).to include(%(target="playlist_card_#{playlist.id}"))
    end

    it "removes the memberships but keeps the videos" do
      playlist = create(:playlist, user: member)
      video = create(:video, visibility: :public)
      create(:playlist_item, playlist: playlist, video: video, position: 1)

      expect { delete playlist_path(playlist) }.to change(PlaylistItem, :count).by(-1)
      expect(Video.exists?(video.id)).to be(true)
    end

    it "404s a non-owner's playlist and keeps it" do
      others = create(:playlist, user: create(:user), title: "Not mine")
      delete playlist_path(others)
      expect(response).to have_http_status(:not_found)
      expect(Playlist.exists?(others.id)).to be(true)
    end

    it "refuses to delete the auto 'Videos you liked' playlist" do
      liked = member.liked_playlist
      delete playlist_path(liked)
      expect(response).to have_http_status(:not_found)
      expect(Playlist.exists?(liked.id)).to be(true)
    end
  end

  describe "GET /playlists/new" do
    it "renders the create modal" do
      get new_playlist_path
      expect(response).to have_http_status(:ok)
      expect(response.body).to include("playlist[title]")
    end
  end

  describe "POST /playlists (player context, with slug)" do
    let(:video) { create(:video, :with_thumbnail, visibility: :public) }

    it "creates the playlist and returns a row for the video plus a reset" do
      post playlists_path, params: { playlist: { title: "Faves" }, slug: video.slug },
           headers: { "Accept" => "text/vnd.turbo-stream.html" }

      expect(response.media_type).to eq("text/vnd.turbo-stream.html")
      expect(response.body).to include('action="append" target="playlist-add-list"')
      expect(response.body).to include('action="replace" target="playlist-add-create"')
      expect(response.body).to include("Faves")
      playlist = member.playlists.find_by(title: "Faves")
      expect(playlist).to be_present
      # New row is a toggle for this video (not yet added).
      expect(response.body).to include(toggle_playlist_video_path(playlist_id: playlist.id, slug: video.slug))
    end

    it "rejects a blank title (422) and re-renders the inline form" do
      video # create the video (and its uploader) before measuring
      expect {
        post playlists_path, params: { playlist: { title: "" }, slug: video.slug },
             headers: { "Accept" => "text/vnd.turbo-stream.html" }
      }.not_to change(member.playlists, :count)
      expect(response).to have_http_status(:unprocessable_content)
      expect(response.body).to include('target="playlist-add-create"')
    end
  end
end
