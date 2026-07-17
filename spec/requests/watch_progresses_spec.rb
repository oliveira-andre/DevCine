require 'rails_helper'

RSpec.describe "WatchProgresses", type: :request do
  let(:member) { create(:user, password: "password123") }

  before { post session_path, params: { email_address: member.email_address, password: "password123" } }

  describe "POST /playing/:slug/progress" do
    it "saves the resume position and feeds the home Last watched rail" do
      video = create(:video, :with_file, :with_thumbnail, visibility: :public)
      post player_progress_path(video.slug), params: { position: 120, duration: 600 }
      expect(response).to have_http_status(:no_content)
      expect(member.watch_progresses.find_by(video:).position_seconds).to eq(120)

      get root_path
      expect(response.body).to include("Last watched")
    end

    it "returns 404 for a private video of another user" do
      video = create(:video, :with_file, visibility: :private, uploader: create(:user))
      post player_progress_path(video.slug), params: { position: 10 }
      expect(response).to have_http_status(:not_found)
    end
  end

  describe "resume on the player page" do
    it "exposes the saved position to the player" do
      video = create(:video, :with_file, visibility: :public)
      WatchProgress.record!(member, video, position: 77, duration: 600)

      get player_path(video.slug)
      expect(response.body).to include('data-player-resume-value="77"')
    end

    it "restarts from zero when the video was completed" do
      video = create(:video, :with_file, visibility: :public)
      WatchProgress.record!(member, video, position: 590, duration: 600)

      get player_path(video.slug)
      expect(response.body).to include('data-player-resume-value="0"')
    end
  end
end
