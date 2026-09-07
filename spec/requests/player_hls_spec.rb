require "rails_helper"

# Serving the HLS package: policy-gated, traversal-proof, typed.
RSpec.describe "Player HLS", type: :request do
  let(:member) { create(:user, password: "password123") }
  let(:video) { create(:video, :with_file, visibility: :public, hls_ready_at: Time.current) }
  let(:base) { HlsPackager.dir_for(video) }

  before do
    post session_path, params: { email_address: member.email_address, password: "password123" }
    FileUtils.mkdir_p(base.join("video"))
    base.join("master.m3u8").write("#EXTM3U\n")
    base.join("video/seg_0000.m4s").write("segment-bytes")
  end

  after { FileUtils.rm_rf(base) }

  it "serves the master playlist and segments with the right types" do
    get hls_player_path(video.slug, rest: "master.m3u8")
    expect(response).to have_http_status(:ok)
    expect(response.media_type).to eq("application/vnd.apple.mpegurl")

    get hls_player_path(video.slug, rest: "video/seg_0000.m4s")
    expect(response).to have_http_status(:ok)
    expect(response.media_type).to eq("video/iso.segment")
    expect(response.headers["Cache-Control"]).to include("max-age=31556952")
  end

  it "404s on path traversal and unknown types" do
    get hls_player_path(video.slug, rest: "../../../config/master.key")
    expect(response).to have_http_status(:not_found)

    base.join("evil.rb").write("boom")
    get hls_player_path(video.slug, rest: "evil.rb")
    expect(response).to have_http_status(:not_found)
  end

  it "is policy-gated like watching the video" do
    hidden = create(:video, :with_file, visibility: :private, hls_ready_at: Time.current)
    get hls_player_path(hidden.slug, rest: "master.m3u8")
    expect(response).to have_http_status(:not_found)
  end

  it "the player page points at the master once packaged" do
    get player_path(video.slug)
    expect(response.body).to include(hls_player_path(video.slug, rest: "master.m3u8"))

    video.update!(hls_ready_at: nil)
    get player_path(video.slug)
    expect(response.body).to include("/rails/active_storage/blobs/redirect/")
  end
end
