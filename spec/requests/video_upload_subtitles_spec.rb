require 'rails_helper'

RSpec.describe "Uploading subtitles with a video", type: :request do
  let(:member) { create(:user, password: "password123") }

  before { post session_path, params: { email_address: member.email_address, password: "password123" } }

  def srt_upload(filename: "captions.srt", body: nil)
    body ||= "1\n00:00:01,000 --> 00:00:04,000\nHello world\n"
    Rack::Test::UploadedFile.new(StringIO.new(body), "application/x-subrip", original_filename: filename)
  end

  def video_upload
    Rack::Test::UploadedFile.new(
      Rails.root.join("spec/fixtures/files/sample_image.jpg"), "video/mp4", original_filename: "clip.mp4"
    )
  end

  def upload(subtitles_attributes)
    post videos_path, params: {
      video: {
        title: "Holiday Clip", maturity_rating: "L", visibility: "public",
        file: video_upload, subtitles_attributes: subtitles_attributes
      }
    }
  end

  it "attaches a subtitle track to the new video" do
    upload("0" => { file: srt_upload, language: "portuguese" })

    video = member.uploaded_videos.find_by(title: "Holiday Clip")
    expect(video).to be_present
    expect(video.subtitles.count).to eq(1)

    track = video.subtitles.first
    expect(track.language).to eq("portuguese")
    expect(track.file).to be_attached
    expect(track.file.filename.to_s).to eq("captions.srt")
  end

  it "attaches several tracks in one upload" do
    upload(
      "0" => { file: srt_upload(filename: "en.srt"), language: "english" },
      "1" => { file: srt_upload(filename: "pt.srt"), language: "portuguese" }
    )

    video = member.uploaded_videos.find_by(title: "Holiday Clip")
    expect(video.subtitles.pluck(:language)).to contain_exactly("english", "portuguese")
  end

  # The form always renders one row, so an uploader who wants no subtitles
  # submits an empty one. That is a skipped slot, not a validation error.
  it "ignores an untouched row" do
    upload("0" => { file: "", language: "" })

    video = member.uploaded_videos.find_by(title: "Holiday Clip")
    expect(video).to be_present
    expect(video.subtitles).to be_empty
  end

  it "ignores an untouched row even when a language was picked by accident" do
    upload("0" => { file: "", language: "english" })

    expect(member.uploaded_videos.find_by(title: "Holiday Clip").subtitles).to be_empty
  end

  it "keeps the good tracks and drops the blank ones" do
    upload(
      "0" => { file: srt_upload(filename: "en.srt"), language: "english" },
      "1" => { file: "", language: "" }
    )

    expect(member.uploaded_videos.find_by(title: "Holiday Clip").subtitles.count).to eq(1)
  end

  describe "rejections" do
    it "refuses a file that is not an .srt, without creating the video" do
      upload("0" => { file: srt_upload(filename: "captions.vtt"), language: "english" })

      expect(response).to have_http_status(:unprocessable_entity)
      expect(member.uploaded_videos.find_by(title: "Holiday Clip")).to be_nil
      expect(response.body).to include("must be an .srt file")
    end

    it "refuses a subtitle with no language" do
      upload("0" => { file: srt_upload, language: "" })

      expect(response).to have_http_status(:unprocessable_entity)
      expect(member.uploaded_videos.find_by(title: "Holiday Clip")).to be_nil
      expect(response.body).to include("Language")
    end

    it "re-renders the form with a subtitle row still available" do
      upload("0" => { file: srt_upload(filename: "captions.vtt"), language: "english" })

      expect(response.body).to include("subtitles_attributes")
      expect(response.body).to include("Add another subtitle")
    end
  end

  # The uploaded track has to be usable by the player, not merely stored.
  it "serves the uploaded track to the player as WebVTT" do
    upload("0" => { file: srt_upload, language: "english" })
    video = member.uploaded_videos.find_by(title: "Holiday Clip")
    track = video.subtitles.first

    get subtitle_player_path(video.slug, track.id)

    expect(response).to have_http_status(:ok)
    expect(response.media_type).to eq("text/vtt")
    expect(response.body).to start_with("WEBVTT")
    expect(response.body).to include("00:00:01.000 --> 00:00:04.000")
  end

  it "offers the track on the player page" do
    upload("0" => { file: srt_upload, language: "english" })
    video = member.uploaded_videos.find_by(title: "Holiday Clip")

    get player_path(video.slug)

    expect(response.body).to include(subtitle_player_path(video.slug, video.subtitles.first.id))
  end
end
