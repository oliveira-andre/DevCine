require 'rails_helper'

RSpec.describe "Thumbnail suggestions", type: :request do
  let(:uploader) { create(:user, password: "password123") }

  def sign_in_as(user)
    post session_path, params: { email_address: user.email_address, password: "password123" }
  end

  # Stand in for ffmpeg: three distinguishable JPEGs, so tests don't depend on
  # the binary being installed.
  def fake_frames(count = 3)
    Array.new(count) do |i|
      file = Tempfile.new([ "frame", ".jpg" ], binmode: true)
      file.write("\xFF\xD8".b + ("frame-#{i}" * (i + 2)).b)
      file.rewind
      file
    end
  end

  def video_with_candidates(count: 3, owner: uploader)
    video = create(:video, :with_file, uploader: owner, title: "Needs A Face")
    extractor = class_double(VideoFrameExtractor)
    allow(extractor).to receive(:call)
      .and_return(VideoFrameExtractor::Result.new(frames: fake_frames(count), error: nil))
    video.suggest_thumbnails!(extractor: extractor)
    video.reload
  end

  describe "Video#suggest_thumbnails!" do
    it "keeps the frames as candidates without touching the thumbnail" do
      video = video_with_candidates

      expect(video.thumbnail_candidates.count).to eq(3)
      expect(video.thumbnail).not_to be_attached
      expect(video).to be_awaiting_thumbnail_choice
    end

    it "leaves an uploader's own thumbnail alone" do
      video = create(:video, :with_file, :with_thumbnail, uploader: uploader)

      expect(video.suggest_thumbnails!).to be(false)
      expect(video.thumbnail_candidates).not_to be_attached
    end

    it "does nothing when there is no video file" do
      expect(create(:video, uploader: uploader).suggest_thumbnails!).to be(false)
    end

    # An upload must survive a broken or missing ffmpeg.
    it "reports false when extraction produced nothing" do
      video = create(:video, :with_file, uploader: uploader)
      extractor = class_double(VideoFrameExtractor)
      allow(extractor).to receive(:call)
        .and_return(VideoFrameExtractor::Result.new(frames: [], error: "ffmpeg is unavailable"))

      expect(video.suggest_thumbnails!(extractor: extractor)).to be(false)
      expect(video.thumbnail_candidates).not_to be_attached
    end

    # Regression: attachment ids are random UUIDs and all three share a
    # created_at, so ordering by either shuffles the grid between renders.
    it "returns the candidates in a stable order across calls" do
      video = video_with_candidates

      names = 3.times.map { video.reload.ordered_thumbnail_candidates.map { |b| b.filename.to_s } }

      expect(names.uniq.size).to eq(1)
      expect(names.first).to eq(%w[suggestion-01.jpg suggestion-02.jpg suggestion-03.jpg])
    end
  end

  describe "choosing" do
    before { sign_in_as(uploader) }

    it "promotes the chosen frame and clears the rest" do
      video = video_with_candidates
      chosen = video.ordered_thumbnail_candidates.last
      # Accepting purges the candidates, so capture what to compare against
      # while the blob still has a file behind it.
      chosen_name = chosen.filename.to_s
      chosen_bytes = chosen.download

      patch thumbnail_suggestions_video_path(video), params: { signed_id: chosen.signed_id }

      video.reload
      expect(video.thumbnail).to be_attached
      expect(video.thumbnail.filename.to_s).to eq(chosen_name)
      expect(video.thumbnail.download).to eq(chosen_bytes)
      expect(video.thumbnail_candidates).not_to be_attached
    end

    it "applies exactly the frame that was asked for" do
      video = video_with_candidates
      first, _second, third = video.ordered_thumbnail_candidates
      first_bytes = first.download
      third_bytes = third.download

      patch thumbnail_suggestions_video_path(video), params: { signed_id: third.signed_id }

      expect(video.reload.thumbnail.download).to eq(third_bytes)
      expect(video.thumbnail.download).not_to eq(first_bytes)
    end

    it "refuses a blob that is not one of this video's candidates" do
      video = video_with_candidates
      other = video_with_candidates
      foreign = other.ordered_thumbnail_candidates.first

      patch thumbnail_suggestions_video_path(video), params: { signed_id: foreign.signed_id }

      expect(video.reload.thumbnail).not_to be_attached
      expect(video.thumbnail_candidates.count).to eq(3)
    end

    it "shrugs off a nonsense signed id" do
      video = video_with_candidates

      patch thumbnail_suggestions_video_path(video), params: { signed_id: "not-a-real-id" }

      expect(video.reload.thumbnail).not_to be_attached
    end

    it "drops the candidates when declined" do
      video = video_with_candidates

      delete thumbnail_suggestions_video_path(video)

      video.reload
      expect(video.thumbnail).not_to be_attached
      expect(video.thumbnail_candidates).not_to be_attached
      expect(video).not_to be_awaiting_thumbnail_choice
    end
  end

  describe "who may choose" do
    it "lets the uploader in" do
      video = video_with_candidates
      sign_in_as(uploader)

      get thumbnail_suggestions_video_path(video)

      expect(response).to have_http_status(:ok)
    end

    it "lets an admin in" do
      video = video_with_candidates
      sign_in_as(create(:user, :admin, password: "password123"))

      get thumbnail_suggestions_video_path(video)

      expect(response).to have_http_status(:ok)
    end

    it "404s for another member, and leaves the video alone" do
      video = video_with_candidates
      sign_in_as(create(:user, password: "password123"))

      get thumbnail_suggestions_video_path(video)
      expect(response).to have_http_status(:not_found)

      patch thumbnail_suggestions_video_path(video),
            params: { signed_id: video.ordered_thumbnail_candidates.first.signed_id }
      expect(response).to have_http_status(:not_found)
      expect(video.reload.thumbnail).not_to be_attached
    end
  end

  describe "returning afterwards" do
    before { sign_in_as(uploader) }

    it "goes back where the admin upload came from" do
      video = video_with_candidates

      delete thumbnail_suggestions_video_path(video), params: { return_to: "/admin/catalog" }

      expect(response).to redirect_to("/admin/catalog")
    end

    # return_to comes from the query string, so it must never send a visitor
    # off-site. Rails' raise_on_open_redirects does NOT cover the last two:
    # Ruby parses them as host-less relative paths, and only the browser turns
    # them into protocol-relative URLs.
    {
      "an absolute URL" => "https://evil.example.com",
      "a protocol-relative URL" => "//evil.example.com",
      "a backslash-escaped URL" => "/\\evil.example.com",
      "a double-backslash URL" => "/\\\\evil.example.com",
      "a tab-smuggled URL" => "/\t/evil.example.com",
      "a newline-smuggled URL" => "/\n/evil.example.com",
      "a scheme with no slashes" => "javascript:alert(1)"
    }.each do |description, hostile|
      it "ignores #{description} in return_to" do
        video = video_with_candidates

        delete thumbnail_suggestions_video_path(video), params: { return_to: hostile }

        expect(response).to redirect_to(account_path)
      end
    end

    it "still honours a genuine in-app path with a query string" do
      video = video_with_candidates

      delete thumbnail_suggestions_video_path(video), params: { return_to: "/admin/catalog?page=2" }

      expect(response).to redirect_to("/admin/catalog?page=2")
    end
  end
end
