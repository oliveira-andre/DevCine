require "rails_helper"

# The read-only audio-track manager modal (MKV ingest): list + download.
RSpec.describe "Admin::AudioTracks", type: :request do
  let(:admin) { create(:user, :admin, password: "password123") }
  let(:video) { create(:video, :with_file, visibility: :public) }

  before { post session_path, params: { email_address: admin.email_address, password: "password123" } }

  it "lists the video's tracks with a download per stripped file" do
    video.audio_tracks.create!(name: "Português", language: "por", position: 1)
    track = video.audio_tracks.create!(name: "English", language: "eng", position: 2)
    track.file.attach(io: StringIO.new("m4a"), filename: "english.m4a", content_type: "audio/mp4")

    get admin_video_audio_tracks_path(video), headers: { "Turbo-Frame" => "modal" }

    expect(response).to have_http_status(:ok)
    expect(response.body).to include("Audio — #{video.title}")
    expect(response.body).to include("Português").and include("English")
    # Default has no separate file (embedded in the MP4); the alternate downloads.
    expect(response.body).to include("embedded in the video file")
    expect(response.body).to include(rails_blob_path(track.file, disposition: "attachment"))
  end

  it "explains when the ingest hasn't run yet" do
    get admin_video_audio_tracks_path(video), headers: { "Turbo-Frame" => "modal" }
    expect(response.body).to include("No audio tracks recorded yet")
  end

  it "blocks non-admins" do
    post session_path, params: { email_address: create(:user, password: "password123").email_address,
                                 password: "password123" }
    get admin_video_audio_tracks_path(video)
    expect(response).to redirect_to(root_path)
  end

  it "links the manager from the catalog slot actions" do
    serie = create(:serie, title: "Audio Linked Show")
    season = serie.seasons.create!(name: "Season 1", position: 1)
    episode_video = create(:video, :with_file, kind: :episode, visibility: :public)
    season.episodes.create!(video: episode_video, title: "Episode 1", position: 1)

    get admin_catalog_item_path("serie", serie)
    expect(response.body).to include(admin_video_audio_tracks_path(episode_video))
  end
end
