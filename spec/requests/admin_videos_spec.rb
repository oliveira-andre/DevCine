require 'rails_helper'

RSpec.describe "Admin videos", type: :request do
  let(:admin) { create(:user, :admin, password: "password123") }

  def sign_in_as(user)
    post session_path, params: { email_address: user.email_address, password: "password123" }
  end

  it "turns a non-admin away" do
    sign_in_as(create(:user, password: "password123"))
    get admin_videos_path
    expect(response).to redirect_to(root_path)
  end

  context "as an admin" do
    before { sign_in_as(admin) }

    describe "GET /admin/videos" do
      it "lists non-live videos and excludes lives" do
        create(:video, title: "A Standalone Clip", kind: :standalone, visibility: :public)
        create(:video, :live, title: "A Live Stream")

        get admin_videos_path

        expect(response.body).to include("A Standalone Clip")
        expect(response.body).not_to include("A Live Stream")
      end

      it "searches by title" do
        create(:video, title: "Searchable Clip", visibility: :public)
        create(:video, title: "Other Clip", visibility: :public)

        get admin_videos_path(q: "Searchable")

        expect(response.body).to include("Searchable Clip")
        expect(response.body).not_to include("Other Clip")
      end

      # A private title is masked until the admin unlocks their PIN, so the
      # filters are asserted by which public row survives / disappears rather
      # than by the hidden title.
      it "filters by kind, visibility and status" do
        public_feature = create(:video, title: "Feature Public Ready", kind: :feature, visibility: :public, status: :ready)
        private_standalone = create(:video, title: "Private Standalone", kind: :standalone, visibility: :private, status: :uploading)

        get admin_videos_path(kind: "feature")
        expect(response.body).to include("admin_video_row_#{public_feature.id}")
        expect(response.body).not_to include("admin_video_row_#{private_standalone.id}")

        get admin_videos_path(visibility: "private")
        expect(response.body).to include("admin_video_row_#{private_standalone.id}")
        expect(response.body).not_to include("admin_video_row_#{public_feature.id}")

        get admin_videos_path(status: "uploading")
        expect(response.body).to include("admin_video_row_#{private_standalone.id}")
        expect(response.body).not_to include("admin_video_row_#{public_feature.id}")
      end

      it "ignores a bogus enum filter value" do
        create(:video, title: "Still Shown", visibility: :public)

        get admin_videos_path(kind: "nonsense")

        expect(response.body).to include("Still Shown")
      end
    end

    describe "GET /admin/videos/:slug" do
      it "shows the video's metadata and its subtitle manager" do
        video = create(:video, :with_file, title: "Detailed Clip", visibility: :public)

        get admin_video_path(video)

        expect(response).to have_http_status(:ok)
        expect(response.body).to include("Detailed Clip")
        expect(response.body).to include("Subtitles")
      end
    end

    describe "PATCH /admin/videos/:slug" do
      let(:video) { create(:video, :with_file, title: "Old", visibility: :public) }

      it "updates the metadata" do
        patch admin_video_path(video),
              params: { video: { title: "New Title", description: "d", maturity_rating: "A12" } }

        video.reload
        expect(video.title).to eq("New Title")
        expect(video.maturity_rating).to eq("A12")
      end

      it "rejects restricted visibility without an A18 rating" do
        patch admin_video_path(video),
              params: { video: { title: "Old", visibility: "restricted", maturity_rating: "L" } }

        expect(response).to have_http_status(:unprocessable_entity)
        expect(video.reload.visibility).to eq("public")
      end
    end

    describe "DELETE /admin/videos/:slug" do
      it "removes the row from the list" do
        video = create(:video, :with_file, title: "List Delete", visibility: :public)

        delete admin_video_path(video)

        expect(response.body).to include("admin_video_row_#{video.id}")
        expect(Video.exists?(video.id)).to be(false)
      end

      it "redirects to the list when deleted from the detail page" do
        video = create(:video, :with_file, title: "Detail Delete", visibility: :public)

        delete admin_video_path(video, back_to_index: true)

        expect(response).to have_http_status(:see_other)
        expect(response).to redirect_to(admin_videos_path)
        expect(Video.exists?(video.id)).to be(false)
      end
    end
  end
end
