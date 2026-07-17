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
