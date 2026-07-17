require 'rails_helper'

RSpec.describe "VideoViews", type: :request do
  let(:member) { create(:user, password: "password123") }

  before { post session_path, params: { email_address: member.email_address, password: "password123" } }

  describe "POST /playing/:slug/views" do
    it "records the video in the viewer's history" do
      video = create(:video, :with_file, visibility: :public)
      expect { post player_views_path(video.slug) }.to change { member.video_views.count }.by(1)
      expect(response).to have_http_status(:no_content)
    end

    it "refreshes without duplicating on repeat" do
      video = create(:video, :with_file, visibility: :public)
      post player_views_path(video.slug)
      expect { post player_views_path(video.slug) }.not_to(change { member.video_views.count })
    end

    it "returns 404 for a private video of another user" do
      video = create(:video, :with_file, visibility: :private, uploader: create(:user))
      post player_views_path(video.slug)
      expect(response).to have_http_status(:not_found)
    end
  end
end
