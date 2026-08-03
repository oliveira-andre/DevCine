require 'rails_helper'

RSpec.describe "Admin playlists", type: :request do
  let(:admin) { create(:user, :admin, password: "password123") }
  let(:owner) { create(:user, email_address: "owner@example.com") }

  def sign_in_as(user)
    post session_path, params: { email_address: user.email_address, password: "password123" }
  end

  it "turns a non-admin away" do
    sign_in_as(create(:user, password: "password123"))

    get admin_playlists_path

    expect(response).to redirect_to(root_path)
  end

  context "as an admin" do
    before { sign_in_as(admin) }

    # Unlike the public browse, moderation needs to see everything — each row
    # carries a visibility badge so nothing is ambiguous.
    it "lists playlists of every visibility" do
      create(:playlist, user: owner, title: "Open List", visibility: :public)
      create(:playlist, user: owner, title: "Link Only List", visibility: :unlisted)
      create(:playlist, user: owner, title: "Closed List", visibility: :private)

      get admin_playlists_path

      expect(response).to have_http_status(:ok)
      expect(response.body).to include("Open List")
      expect(response.body).to include("Link Only List")
      expect(response.body).to include("Closed List")
    end

    it "searches by title or by owner email" do
      create(:playlist, user: owner, title: "Jazz Essentials")
      create(:playlist, user: create(:user, email_address: "other@example.com"), title: "Rock Anthems")

      get admin_playlists_path(q: "jazz")
      expect(response.body).to include("Jazz Essentials")
      expect(response.body).not_to include("Rock Anthems")

      get admin_playlists_path(q: "owner@example.com")
      expect(response.body).to include("Jazz Essentials")
      expect(response.body).not_to include("Rock Anthems")
    end

    it "links each row to its owner's admin page" do
      create(:playlist, user: owner, title: "Owned List")

      get admin_playlists_path

      expect(response.body).to include(admin_user_path(owner))
    end

    it "marks a saved copy as one" do
      source = create(:playlist, user: owner, title: "Original", visibility: :public)
      saver = create(:user)
      source.save_copy_for(saver, AuthContext.new(user: saver, pin_unlocked: false))

      get admin_playlists_path

      expect(response.body).to include("Saved copy")
    end

    # Same PIN rule as the user pages: a member title the admin is not cleared
    # for must not leak through a playlist's expanded member list.
    it "masks member titles the admin cannot see yet" do
      playlist = create(:playlist, user: owner, title: "Mixed List", visibility: :public)
      create(:playlist_item, playlist: playlist, position: 1,
                             video: create(:video, title: "Open Track", visibility: :public))
      create(:playlist_item, playlist: playlist, position: 2,
                             video: create(:video, title: "Closed Track", visibility: :private))

      get admin_playlists_path

      expect(response.body).to include("Open Track")
      expect(response.body).not_to include("Closed Track")
      expect(response.body).to include("hidden until you unlock")
    end

    it "deletes a playlist without touching its videos" do
      playlist = create(:playlist, user: owner, title: "Doomed List")
      video = create(:video, visibility: :public)
      create(:playlist_item, playlist: playlist, video: video, position: 1)

      expect {
        delete admin_playlist_path(playlist)
      }.to change(Playlist, :count).by(-1)

      expect(video.reload).to be_persisted
      expect(response.body).to include("admin_playlist_row_#{playlist.id}")
    end

    it "says so when there is nothing to show" do
      Playlist.destroy_all

      get admin_playlists_path

      expect(response.body).to include("No playlists yet.")
    end
  end
end
