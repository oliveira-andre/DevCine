require 'rails_helper'

# The account upload saves itself as a draft once it has a title and a file, so
# ffmpeg can read the real upload before the viewer commits. The admin catalog
# upload has no "before save" moment — the video already exists from an import
# and dropping the file IS the update — so it just gets shown the options.
RSpec.describe "Upload thumbnail suggestions", type: :request do
  let(:member) { create(:user, password: "password123") }

  def sign_in_as(user)
    post session_path, params: { email_address: user.email_address, password: "password123" }
  end

  def video_upload
    Rack::Test::UploadedFile.new(
      Rails.root.join("spec/fixtures/files/sample_video.mp4"), "video/mp4",
      original_filename: "clip.mp4"
    )
  end

  def stub_extractor(frames:)
    tempfiles = Array.new(frames) do |i|
      file = Tempfile.new([ "frame", ".jpg" ], binmode: true)
      file.write("\xFF\xD8".b + "frame-#{i}".b)
      file.rewind
      file
    end
    allow(VideoFrameExtractor).to receive(:call)
      .and_return(VideoFrameExtractor::Result.new(frames: tempfiles, error: nil))
  end

  def stub_extractor_failure
    allow(VideoFrameExtractor).to receive(:call)
      .and_return(VideoFrameExtractor::Result.new(frames: [], error: "ffmpeg is unavailable"))
  end

  describe "the account upload" do
    before { sign_in_as(member) }

    def create_draft(extra = {})
      post videos_path, params: {
        draft: "1",
        video: { title: "Fresh Clip", maturity_rating: "L", visibility: "public",
                 file: video_upload }.merge(extra)
      }
      member.uploaded_videos.find_by(title: "Fresh Clip")
    end

    describe "saving the draft" do
      it "keeps it private and unfinished so it cannot reach a listing" do
        draft = create_draft

        expect(draft).to be_uploading
        expect(draft).to be_visibility_private
        expect(policy_scope_titles).not_to include("Fresh Clip")
      end

      it "answers with the form in update mode, carrying the suggestions frame" do
        draft = create_draft

        expect(response.body).to include("Finish your upload")
        expect(response.body).to include(video_path(draft))
        expect(response.body).to include("thumbnail_suggestions")
        # The frame is lazy: nothing has been extracted yet at this point.
        expect(draft.thumbnail_candidates).not_to be_attached
      end

      # No JavaScript means no autosave, so a plain submit must still work.
      it "finishes outright when the draft flag is absent" do
        post videos_path, params: {
          video: { title: "One Shot", maturity_rating: "L", visibility: "public",
                   file: video_upload }
        }

        video = member.uploaded_videos.find_by(title: "One Shot")
        expect(video).to be_ready
        expect(video).to be_visibility_public
        expect(response.body).not_to include("Finish your upload")
      end
    end

    describe "the suggestions frame" do
      it "extracts on its first fetch and offers a radio per frame" do
        stub_extractor(frames: 3)
        draft = create_draft

        get thumbnail_suggestions_video_path(draft),
            headers: { "Turbo-Frame" => "thumbnail_suggestions" }

        expect(response.body).to include("video[thumbnail_signed_id]")
        expect(draft.reload.thumbnail_candidates.count).to eq(3)
      end

      it "does not re-extract on a second fetch" do
        stub_extractor(frames: 3)
        draft = create_draft
        get thumbnail_suggestions_video_path(draft), headers: { "Turbo-Frame" => "thumbnail_suggestions" }

        expect(VideoFrameExtractor).not_to receive(:call)
        get thumbnail_suggestions_video_path(draft), headers: { "Turbo-Frame" => "thumbnail_suggestions" }

        expect(draft.reload.thumbnail_candidates.count).to eq(3)
      end

      it "says so when ffmpeg produced nothing, without breaking the form" do
        stub_extractor_failure
        draft = create_draft

        get thumbnail_suggestions_video_path(draft), headers: { "Turbo-Frame" => "thumbnail_suggestions" }

        expect(response).to have_http_status(:ok)
        expect(response.body).to include("Couldn’t read any frames")
      end
    end

    describe "finishing" do
      it "applies the chosen frame and the viewer's real visibility" do
        stub_extractor(frames: 3)
        draft = create_draft
        draft.suggest_thumbnails!
        chosen = draft.reload.ordered_thumbnail_candidates.last
        chosen_bytes = chosen.download

        patch video_path(draft), params: {
          video: { title: "Fresh Clip", maturity_rating: "L", visibility: "public",
                   thumbnail_signed_id: chosen.signed_id }
        }

        draft.reload
        expect(draft).to be_ready
        expect(draft).to be_visibility_public
        expect(draft.thumbnail.download).to eq(chosen_bytes)
        expect(draft.thumbnail_candidates).not_to be_attached
      end

      it "finishes without a thumbnail when nothing was picked" do
        stub_extractor(frames: 3)
        draft = create_draft
        draft.suggest_thumbnails!

        patch video_path(draft), params: {
          video: { title: "Fresh Clip", maturity_rating: "L", visibility: "public" }
        }

        draft.reload
        expect(draft).to be_ready
        expect(draft.thumbnail).not_to be_attached
        # Unpicked frames must not linger in storage.
        expect(draft.thumbnail_candidates).not_to be_attached
      end

      it "will not finish somebody else's draft" do
        draft = create_draft
        sign_in_as(create(:user, password: "password123"))

        patch video_path(draft), params: { video: { title: "Stolen" } }

        expect(response).to have_http_status(:not_found)
        expect(draft.reload.title).to eq("Fresh Clip")
      end
    end

    def policy_scope_titles
      VideoPolicy::Scope.new(AuthContext.new(user: member, pin_unlocked: false), Video)
                        .resolve.pluck(:title)
    end
  end

  describe "the admin catalog upload" do
    let(:admin) { create(:user, :admin, password: "password123") }
    let(:movie) { create(:movie, title: "Placeholder Movie") }

    before { sign_in_as(admin) }

    it "shows the options after the file lands, with a way back to the item" do
      stub_extractor(frames: 3)
      placeholder = movie.video

      post upload_admin_catalog_item_path("movie", movie.id),
           params: { file: video_upload, video_id: placeholder.id }

      expect(placeholder.reload.thumbnail_candidates.count).to eq(3)
      expect(response).to redirect_to(
        thumbnail_suggestions_video_path(
          placeholder, return_to: admin_catalog_item_path("movie", movie.id)
        )
      )
    end

    it "finishes as before when ffmpeg gives nothing" do
      stub_extractor_failure
      placeholder = movie.video

      post upload_admin_catalog_item_path("movie", movie.id),
           params: { file: video_upload, video_id: placeholder.id }

      expect(response).to redirect_to(admin_catalog_item_path("movie", movie.id))
      expect(flash[:notice]).to match(/saved successfully/)
    end
  end

  # One pass through the real binary so the stubs can't all agree on a fiction.
  describe "end to end with the real ffmpeg", :ffmpeg do
    before { sign_in_as(member) }

    it "extracts real frames from the draft and applies the picked one" do
      post videos_path, params: {
        draft: "1",
        video: { title: "Real Frames", maturity_rating: "L", visibility: "public",
                 file: video_upload }
      }
      draft = member.uploaded_videos.find_by(title: "Real Frames")

      get thumbnail_suggestions_video_path(draft), headers: { "Turbo-Frame" => "thumbnail_suggestions" }
      expect(draft.reload.thumbnail_candidates.count).to eq(VideoFrameExtractor::FRAME_COUNT)

      chosen = draft.ordered_thumbnail_candidates.second
      chosen_bytes = chosen.download
      expect(chosen_bytes[0, 2].unpack1("H*")).to eq("ffd8") # a real JPEG

      patch video_path(draft), params: {
        video: { title: "Real Frames", maturity_rating: "L", visibility: "public",
                 thumbnail_signed_id: chosen.signed_id }
      }

      draft.reload
      expect(draft).to be_ready
      expect(draft.thumbnail.download).to eq(chosen_bytes)
    end
  end
end
