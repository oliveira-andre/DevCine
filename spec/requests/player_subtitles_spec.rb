require 'rails_helper'

# Feature 012: the WebVTT track endpoint, policy-scoped through the video.
RSpec.describe "Player subtitles (vtt)", type: :request do
  let(:member) { create(:user, password: "password123") }
  before { post session_path, params: { email_address: member.email_address, password: "password123" } }

  it "serves the track as text/vtt" do
    video = create(:video, :with_file, visibility: :public)
    sub = create(:subtitle, :with_file, video: video, is_default: true)

    get subtitle_player_path(video.slug, sub.id)
    expect(response).to have_http_status(:ok)
    expect(response.media_type).to eq("text/vtt")
    expect(response.body).to start_with("WEBVTT")
    expect(response.body).to include("00:00:01.000 --> 00:00:04.000")
  end

  it "404s for a private video's track requested by a non-owner" do
    video = create(:video, :with_file, visibility: :private, uploader: create(:user))
    sub = create(:subtitle, :with_file, video: video)

    get subtitle_player_path(video.slug, sub.id)
    expect(response).to have_http_status(:not_found)
  end
end
