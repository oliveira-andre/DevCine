require 'rails_helper'

# Feature 012: persisting the viewer's subtitle preferences + the player page
# embedding tracks/prefs for file videos (not live embeds).
RSpec.describe "Settings::Subtitles", type: :request do
  let(:member) { create(:user, password: "password123") }
  before { post session_path, params: { email_address: member.email_address, password: "password123" } }

  describe "PATCH /settings/subtitle" do
    it "persists enabled + appearance fields" do
      patch settings_subtitle_path, params: {
        subtitles_enabled: true, subtitle_text_color: "#00FF00",
        subtitle_font_size: 150, subtitle_font_weight: 700
      }
      expect(response).to have_http_status(:no_content)
      member.reload
      expect(member.subtitles_enabled).to be(true)
      expect(member.subtitle_text_color).to eq("#00FF00")
      expect(member.subtitle_font_size).to eq(150)
      expect(member.subtitle_font_weight).to eq(700)
    end

    it "stores a blank background as transparent" do
      patch settings_subtitle_path, params: { subtitle_background_color: "" }
      expect(member.reload.subtitle_background_color).to be_blank
    end

    it "rejects an invalid value" do
      patch settings_subtitle_path, params: { subtitle_font_weight: 450 }
      expect(response).to have_http_status(:unprocessable_content)
    end
  end

  describe "player page embeds subtitle data" do
    it "includes tracks + prefs for a file video" do
      video = create(:video, :with_file, visibility: :public)
      create(:subtitle, :with_file, video: video, is_default: true, language: :english)
      get player_path(video.slug)
      expect(response.body).to include("data-player-source-subtitles-value")
      expect(response.body).to include('data-controller="subtitle-settings"')
    end

    it "renders no subtitle controls for a live embed" do
      live = create(:video, :live, visibility: :public)
      get player_path(live.slug)
      expect(response.body).not_to include('data-controller="subtitle-settings"')
    end
  end
end
