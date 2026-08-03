require 'rails_helper'

RSpec.describe "Saving a playlist", type: :request do
  let(:member) { create(:user, password: "password123") }
  let(:owner) { create(:user) }
  let!(:source) { create(:playlist, user: owner, title: "Road Trip", visibility: :public) }

  def sign_in_as(user)
    post session_path, params: { email_address: user.email_address, password: "password123" }
  end

  context "as a signed-in member" do
    before { sign_in_as(member) }

    it "saves a copy under the current user and redirects to it" do
      video = create(:video, visibility: :public)
      create(:playlist_item, playlist: source, video: video, position: 1)

      expect {
        post save_playlist_path(source)
      }.to change(member.playlists, :count).by(1)

      copy = member.playlists.find_by(cloned_from: source)
      expect(copy.title).to eq("Road Trip")
      expect(copy.videos).to contain_exactly(video)
      expect(response).to redirect_to(playlist_path(copy))
    end

    it "does not stack up copies when saved twice" do
      post save_playlist_path(source)
      first_copy = member.playlists.find_by(cloned_from: source)

      expect {
        post save_playlist_path(source)
      }.not_to change(member.playlists, :count)

      expect(response).to redirect_to(playlist_path(first_copy))
    end

    it "leaves the original untouched" do
      post save_playlist_path(source)

      expect(source.reload.user).to eq(owner)
      expect(source.title).to eq("Road Trip")
      # The copy lands on the saver, not the owner. (Every user also owns an
      # auto-created "Videos you liked" list, so count the clones directly.)
      expect(owner.playlists.where.not(cloned_from_id: nil)).to be_empty
    end

    # The copy is the saver's own list, so editing it must not reach back.
    it "gives the copy independent membership" do
      video = create(:video, visibility: :public)
      create(:playlist_item, playlist: source, video: video, position: 1)
      post save_playlist_path(source)
      copy = member.playlists.find_by(cloned_from: source)

      copy.playlist_items.destroy_all

      expect(source.reload.videos).to contain_exactly(video)
    end

    it "can save an unlisted playlist reached by link" do
      unlisted = create(:playlist, user: owner, title: "By Link Only", visibility: :unlisted)

      post save_playlist_path(unlisted)

      expect(member.playlists.find_by(cloned_from: unlisted)).to be_present
    end

    # Saving is gated by the same policy as viewing, and a denial 404s rather
    # than 403ing — no existence disclosure (feature 006).
    it "refuses somebody else's private playlist" do
      private_list = create(:playlist, user: owner, title: "Secret", visibility: :private)

      post save_playlist_path(private_list)

      expect(response).to have_http_status(:not_found)
      expect(member.playlists.find_by(cloned_from: private_list)).to be_nil
    end
  end

  it "sends a signed-out visitor to sign in" do
    post save_playlist_path(source)

    expect(response).to redirect_to(new_session_path)
    expect(Playlist.where(cloned_from: source).count).to eq(0)
  end

  describe "the button on the playlist page" do
    it "offers to save somebody else's playlist" do
      sign_in_as(member)

      get playlist_path(source)

      expect(response.body).to include("Save playlist")
    end

    it "shows the saved state once saved, linking to the copy" do
      sign_in_as(member)
      post save_playlist_path(source)
      copy = member.playlists.find_by(cloned_from: source)

      get playlist_path(source)

      expect(response.body).to include("Saved")
      expect(response.body).to include(playlist_path(copy))
      expect(response.body).not_to include("Save playlist")
    end

    it "is absent on your own playlist — there is nothing to save" do
      sign_in_as(owner)

      get playlist_path(source)

      expect(response.body).not_to include("Save playlist")
    end
  end
end
