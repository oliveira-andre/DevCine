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

    it "opens the thumbnail chooser in the modal AND settles the slot row in place" do
      stub_extractor(frames: 3)
      placeholder = movie.video

      post upload_admin_catalog_item_path("movie", movie.id),
           params: { file: video_upload, video_id: placeholder.id },
           headers: { "Accept" => "text/vnd.turbo-stream.html" }

      expect(placeholder.reload.thumbnail_candidates.count).to eq(3)
      # Turbo Streams, not a redirect: the chooser fills the shared modal and
      # the slot row flips to Uploaded behind it — so even a plain ✕ close
      # leaves a correct page.
      expect(response.media_type).to eq("text/vnd.turbo-stream.html")
      expect(response.body).to include('target="modal"')
      expect(response.body).to include("Choose a thumbnail")
      expect(response.body).to include("admin_movie_slot_#{movie.id}")
      # The chooser posts the pick/skip back to the owning catalog item.
      expect(response.body).to include(choose_thumbnail_admin_catalog_item_path("movie", movie.id))
      expect(response.body).to include(skip_thumbnail_admin_catalog_item_path("movie", movie.id))
    end

    it "streams the settled row and a toast when ffmpeg gives nothing" do
      stub_extractor_failure
      placeholder = movie.video

      post upload_admin_catalog_item_path("movie", movie.id),
           params: { file: video_upload, video_id: placeholder.id },
           headers: { "Accept" => "text/vnd.turbo-stream.html" }

      expect(response.media_type).to eq("text/vnd.turbo-stream.html")
      expect(response.body).to include("admin_movie_slot_#{movie.id}")
      expect(response.body).to include("saved successfully")
      expect(response.body).not_to include("Choose a thumbnail")
    end

    it "choosing a frame promotes it and closes the modal without a redirect" do
      placeholder = movie.video
      placeholder.file.attach(io: StringIO.new("bytes"), filename: "m.mp4", content_type: "video/mp4")
      placeholder.thumbnail_candidates.attach(
        io: StringIO.new("f1"), filename: "suggestion-01.jpg", content_type: "image/jpeg"
      )
      chosen = placeholder.ordered_thumbnail_candidates.first

      patch choose_thumbnail_admin_catalog_item_path("movie", movie.id),
            params: { video_id: placeholder.id, signed_id: chosen.signed_id }

      placeholder.reload
      expect(placeholder.thumbnail).to be_attached
      expect(placeholder.thumbnail_candidates.count).to eq(0)
      expect(response.media_type).to eq("text/vnd.turbo-stream.html")
      expect(response.body).to include('action="update" target="modal"')
      expect(response.body).to include("Thumbnail set.")
    end

    it "skipping clears the candidates and closes the modal without a redirect" do
      placeholder = movie.video
      placeholder.thumbnail_candidates.attach(
        io: StringIO.new("f1"), filename: "suggestion-01.jpg", content_type: "image/jpeg"
      )

      delete skip_thumbnail_admin_catalog_item_path("movie", movie.id),
             params: { video_id: placeholder.id }

      expect(placeholder.reload.thumbnail_candidates.count).to eq(0)
      expect(placeholder.thumbnail).not_to be_attached
      expect(response.media_type).to eq("text/vnd.turbo-stream.html")
      expect(response.body).to include('action="update" target="modal"')
    end

    it "rejects a video that does not belong to the item" do
      foreign = create(:video, :with_file)
      foreign.thumbnail_candidates.attach(
        io: StringIO.new("f1"), filename: "suggestion-01.jpg", content_type: "image/jpeg"
      )

      patch choose_thumbnail_admin_catalog_item_path("movie", movie.id),
            params: { video_id: foreign.id, signed_id: "x" }

      expect(response).to have_http_status(:not_found)
      expect(foreign.reload.thumbnail_candidates.count).to eq(1)
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
