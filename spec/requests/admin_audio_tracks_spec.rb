require "rails_helper"

# The audio-track manager modal (MKV ingest): list + download, plus
# add/edit/remove mirroring the subtitle manager. Rendition-changing actions
# discard the HLS package and re-enqueue the packager.
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

  describe "create" do
    let(:file) { Rack::Test::UploadedFile.new(StringIO.new("m4a"), "audio/mp4", original_filename: "spanish.m4a") }

    it "appends a track with its file and re-enqueues the HLS packager" do
      video.audio_tracks.create!(name: "Português", position: 1)
      video.update!(hls_ready_at: Time.current)

      expect {
        post admin_video_audio_tracks_path(video),
             params: { audio_track: { name: "Español", language: "spa", file: file } }
      }.to change(video.audio_tracks, :count).by(1)
        .and have_enqueued_job(HlsPackageJob).with(video)

      track = video.audio_tracks.ordered.last
      expect(track.name).to eq("Español")
      expect(track.position).to eq(2)
      expect(track.file).to be_attached
      # The old package is stale the moment renditions change.
      expect(video.reload.hls_ready_at).to be_nil
      expect(response).to redirect_to(admin_video_audio_tracks_path(video))
    end

    it "rejects a new track without a file" do
      expect {
        post admin_video_audio_tracks_path(video), params: { audio_track: { name: "Español" } }
      }.not_to change(AudioTrack, :count)
      expect(response).to have_http_status(:unprocessable_entity)
      expect(response.body).to include("is required")
    end
  end

  describe "update" do
    it "renames without touching the HLS package" do
      track = video.audio_tracks.create!(name: "Português", position: 1)
      video.update!(hls_ready_at: Time.current)

      expect {
        patch admin_video_audio_track_path(video, track), params: { audio_track: { name: "Português (Brasil)" } }
      }.not_to have_enqueued_job(HlsPackageJob)

      expect(track.reload.name).to eq("Português (Brasil)")
      expect(video.reload.hls_ready_at).to be_present
    end

    it "replacing the file re-enqueues the packager" do
      video.audio_tracks.create!(name: "Português", position: 1)
      track = video.audio_tracks.create!(name: "English", position: 2)
      track.file.attach(io: StringIO.new("old"), filename: "old.m4a", content_type: "audio/mp4")

      replacement = Rack::Test::UploadedFile.new(StringIO.new("new"), "audio/mp4", original_filename: "new.m4a")
      expect {
        patch admin_video_audio_track_path(video, track), params: { audio_track: { file: replacement } }
      }.to have_enqueued_job(HlsPackageJob).with(video)
      expect(track.reload.file.filename.to_s).to eq("new.m4a")
    end
  end

  describe "destroy" do
    it "removes an alternate track and re-enqueues the packager" do
      video.audio_tracks.create!(name: "Português", position: 1)
      track = video.audio_tracks.create!(name: "English", position: 2)

      expect {
        delete admin_video_audio_track_path(video, track)
      }.to change(video.audio_tracks, :count).by(-1)
        .and have_enqueued_job(HlsPackageJob).with(video)
      expect(response.body).to include("admin_audio_track_#{track.id}")
    end

    it "refuses to remove the default track — its sound is embedded in the MP4" do
      track = video.audio_tracks.create!(name: "Português", position: 1)
      expect {
        delete admin_video_audio_track_path(video, track)
      }.not_to change(video.audio_tracks, :count)
      expect(response).to have_http_status(:unprocessable_entity)
    end
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
