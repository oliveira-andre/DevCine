require 'rails_helper'

# Feature 012 (US4): admin subtitle track management.
RSpec.describe "Admin::Subtitles", type: :request do
  let(:admin) { create(:user, :admin, password: "password123") }
  let(:video) { create(:video, :with_file, visibility: :public) }

  def sign_in(user)
    post session_path, params: { email_address: user.email_address, password: "password123" }
  end

  def srt_upload
    Rack::Test::UploadedFile.new(
      StringIO.new("1\n00:00:01,000 --> 00:00:03,000\nHi\n"), "text/plain", original_filename: "en.srt"
    )
  end

  before { sign_in(admin) }

  it "creates a track from an SRT with a language" do
    expect {
      post admin_video_subtitles_path(video),
           params: { subtitle: { file: srt_upload, language: "english", is_default: "1" } }
    }.to change { video.subtitles.count }.by(1)
    # success refreshes the manager modal (redirect followed in-frame)
    expect(response).to redirect_to(new_admin_video_subtitle_path(video))
    expect(video.subtitles.last.language).to eq("english")

    follow_redirect!
    expect(response.body).to include("en.srt")     # filename listed
    expect(response.body).to include("aria-label=\"Remove English track\"") # trash
  end

  it "unsets other defaults when a new default is set" do
    a = create(:subtitle, :with_file, video: video, language: :english, is_default: true)
    patch admin_video_subtitle_path(video, create(:subtitle, :with_file, video: video, language: :spanish)),
          params: { subtitle: { is_default: "1" } },
          headers: { "Accept" => "text/vnd.turbo-stream.html" }
    expect(a.reload.is_default).to be(false)
  end

  it "rejects a non-SRT file" do
    bad = Rack::Test::UploadedFile.new(StringIO.new("x"), "text/vtt", original_filename: "en.vtt")
    expect {
      post admin_video_subtitles_path(video),
           params: { subtitle: { file: bad, language: "english" } },
           headers: { "Accept" => "text/vnd.turbo-stream.html, text/html" }
    }.not_to change { video.subtitles.count }
    expect(response).to have_http_status(:unprocessable_content)
  end

  it "removes a track" do
    sub = create(:subtitle, :with_file, video: video)
    expect {
      delete admin_video_subtitle_path(video, sub), headers: { "Accept" => "text/vnd.turbo-stream.html" }
    }.to change { video.subtitles.count }.by(-1)
  end

  it "blocks non-admins" do
    sign_in(create(:user, password: "password123"))
    get admin_videos_path
    expect(response).to redirect_to(root_path)
  end
end
