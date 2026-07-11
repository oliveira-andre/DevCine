require 'rails_helper'

RSpec.describe "Accounts", type: :request do
  def sign_in(user)
    post session_path, params: { email_address: user.email_address, password: "password123" }
  end

  describe "GET /account (own profile)" do
    let(:member) { create(:user, password: "password123") }
    before { sign_in(member) }

    it "renders the owner profile with action links and all four rails" do
      create(:video, uploader: member, kind: :standalone, visibility: :public)
      create(:like, user: member, likeable: create(:video))
      create(:playlist, :with_videos, user: member, videos_count: 2)
      create(:video_view, user: member, video: create(:video))

      get account_path
      expect(response).to have_http_status(:ok)
      %w[Recent\ uploads Likes Playlists History].each { |t| expect(response.body).to include(t) }
      expect(response.body).to include(edit_settings_password_path)
      expect(response.body).to include(new_video_path)
    end
  end

  describe "GET /account/:slug (public profile, non-owner)" do
    let(:viewer) { create(:user, password: "password123") }
    let(:owner) { create(:user, password: "password123") }

    it "hides actions and History and shows public-only content" do
      create(:video, uploader: owner, kind: :standalone, visibility: :public, title: "Owner Public Clip")
      create(:video, uploader: owner, kind: :standalone, visibility: :private, title: "Owner Private Clip")
      create(:video_view, user: owner, video: create(:video))
      sign_in(viewer)

      get public_account_path(slug: owner.handle)
      expect(response).to have_http_status(:ok)
      expect(response.body).to include("Owner Public Clip")
      expect(response.body).not_to include("Owner Private Clip")
      expect(response.body).not_to include("History")
      expect(response.body).not_to include(new_video_path) # no owner actions
    end

    it "returns 404 for an unknown handle" do
      sign_in(viewer)
      get public_account_path(slug: "does-not-exist")
      expect(response).to have_http_status(:not_found)
    end

    it "shows actions + History when the owner views their own slug" do
      create(:video_view, user: owner, video: create(:video))
      sign_in(owner)
      get public_account_path(slug: owner.handle)
      expect(response.body).to include(new_video_path)
      expect(response.body).to include("History")
    end
  end
end
