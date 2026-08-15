require 'rails_helper'

RSpec.describe "Video uploads", type: :request do
  let(:member) { create(:user, password: "password123") }

  before { post session_path, params: { email_address: member.email_address, password: "password123" } }

  def upload(name, type)
    Rack::Test::UploadedFile.new(Rails.root.join("spec/fixtures/files/#{name}"), type)
  end

  describe "GET /videos/new" do
    it "renders the upload form" do
      get new_video_path
      expect(response).to have_http_status(:ok)
      expect(response.body).to include("Video file")
    end
  end

  describe "POST /videos" do
    it "creates a standalone video owned by the member with chosen metadata" do
      expect {
        post videos_path, params: { video: {
          title: "My Clip", description: "desc", maturity_rating: "A12", visibility: "public",
          file: upload("sample_image.jpg", "video/mp4")
        } }
      }.to change(member.uploaded_videos, :count).by(1)

      video = member.uploaded_videos.order(:created_at).last
      expect(video.kind).to eq("standalone")
      expect(video.visibility).to eq("public")
      expect(video.maturity_rating).to eq("A12")
      expect(video.file).to be_attached
    end

    it "rejects a missing title" do
      post videos_path, params: { video: { title: "", file: upload("sample_image.jpg", "video/mp4") } }
      expect(response).to have_http_status(:unprocessable_content)
    end
  end

  # Large files are streamed to /chunked_uploads first (lib/chunk_uploader);
  # the draft submit then carries only the upload id — same contract as the
  # admin catalog flow, through the member-gated endpoint.
  describe "chunked (resumable) member uploads" do
    let(:upload_id) { "aaaaaaaa-bbbb-4ccc-8ddd-eeeeeeeeeeee" }

    after { FileUtils.rm_rf(ChunkedUpload.dir_for(member)) }

    def stream_chunks(*parts)
      parts.each_with_index do |bytes, index|
        post chunked_uploads_path, params: {
          upload_id: upload_id, index: index,
          chunk: Rack::Test::UploadedFile.new(StringIO.new(bytes), "application/octet-stream",
                                              original_filename: "chunk.bin")
        }
        expect(response).to have_http_status(:ok)
      end
    end

    it "creates a draft from a file streamed in chunks and sweeps the scratch" do
      stream_chunks("part-one-", "part-two")

      expect {
        post videos_path, params: {
          draft: "1", chunked_upload_id: upload_id,
          chunked_upload_filename: "big-clip.mp4", chunked_upload_content_type: "video/mp4",
          video: { title: "Chunked Member Clip", maturity_rating: "L", visibility: "public" }
        }
      }.to change(member.uploaded_videos, :count).by(1)

      video = member.uploaded_videos.order(:created_at).last
      expect(video.file).to be_attached
      expect(video.file.filename.to_s).to eq("big-clip.mp4")
      expect(video.file.download).to eq("part-one-part-two")
      expect(video).to have_attributes(status: "uploading", visibility: "private") # draft held back
      expect(ChunkedUpload.new(member, upload_id).exists?).to be(false)            # scratch swept
    end

    it "still requires a file when neither bytes nor a chunk id arrive" do
      post videos_path, params: { draft: "1", video: { title: "No File" } }
      expect(response).to have_http_status(:unprocessable_content)
    end

    it "rejects chunks from a signed-out visitor" do
      delete session_path
      post chunked_uploads_path, params: {
        upload_id: upload_id, index: 0,
        chunk: Rack::Test::UploadedFile.new(StringIO.new("x"), "application/octet-stream",
                                            original_filename: "chunk.bin")
      }
      expect(response).to redirect_to(new_session_path)
    end

    it "rejects a missing video file" do
      expect {
        post videos_path, params: { video: { title: "No File" } }
      }.not_to change(Video, :count)
      expect(response).to have_http_status(:unprocessable_content)
    end

    it "creates a restricted video when rated A18 (feature 006)" do
      expect {
        post videos_path, params: { video: {
          title: "Gated Clip", visibility: "restricted", maturity_rating: "A18",
          file: upload("sample_image.jpg", "video/mp4")
        } }
      }.to change(member.uploaded_videos.where(visibility: :restricted), :count).by(1)
    end

    it "rejects a restricted video rated below A18" do
      expect {
        post videos_path, params: { video: {
          title: "Bad Gate", visibility: "restricted", maturity_rating: "A14",
          file: upload("sample_image.jpg", "video/mp4")
        } }
      }.not_to change(Video, :count)
      expect(response).to have_http_status(:unprocessable_content)
      expect(response.body).to include("restricted titles must be rated A18")
    end
  end
end
