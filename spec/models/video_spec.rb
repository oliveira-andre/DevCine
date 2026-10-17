require 'rails_helper'

RSpec.describe Video, type: :model do
  subject { build(:video) }

  it "has a valid factory" do
    expect(build(:video)).to be_valid
  end

  describe "associations" do
    it { is_expected.to belong_to(:uploader).class_name("User") }
    it { is_expected.to have_many(:watch_progresses).dependent(:destroy) }
    it { is_expected.to have_many(:episodes).dependent(:destroy) }
    it { is_expected.to have_many(:playlist_items).dependent(:destroy) }

    it "can be destroyed while it is in a playlist" do
      video = create(:video)
      playlist = create(:playlist)
      playlist.playlist_items.create!(video: video, position: 1)
      expect { video.destroy! }.to change(PlaylistItem, :count).by(-1)
    end
  end

  describe "validations" do
    it { is_expected.to validate_presence_of(:title) }
    # duration_seconds is optional (unknown until processing) but positive when present
    it { is_expected.to validate_numericality_of(:duration_seconds).is_greater_than(0).allow_nil }
  end

  # --- Live embed (feature 009) ---
  describe "live embed URL" do
    it "requires a valid https embed URL for a live video" do
      expect(build(:video, kind: :live, live_embed_url: nil)).not_to be_valid
      expect(build(:video, kind: :live, live_embed_url: "")).not_to be_valid
      expect(build(:video, kind: :live, live_embed_url: "http://insecure.example/embed")).not_to be_valid
      expect(build(:video, kind: :live, live_embed_url: "not a url")).not_to be_valid
      expect(build(:video, kind: :live, live_embed_url: "https://www.youtube.com/embed/abc")).to be_valid
    end

    it "rewrites a YouTube /live/ share link to its /embed/ URL" do
      expect(build(:video, live_embed_url: "https://www.youtube.com/live/abc123?si=x").live_embed_url)
        .to eq("https://www.youtube.com/embed/abc123?si=x")
      expect(build(:video, live_embed_url: "https://youtube.com/live/abc123").live_embed_url)
        .to eq("https://youtube.com/embed/abc123")
    end

    it "keeps every other embed URL exactly as entered, even when it contains \"live\"" do
      twitch = "https://player.twitch.tv/?channel=coloniacontraatacalive&parent=cine.codeline.online"
      expect(build(:video, live_embed_url: twitch).live_embed_url).to eq(twitch)
      expect(build(:video, live_embed_url: "https://www.youtube.com/embed/liveabc").live_embed_url)
        .to eq("https://www.youtube.com/embed/liveabc")
      expect(build(:video, live_embed_url: "https://live.example.com/live/abc").live_embed_url)
        .to eq("https://live.example.com/live/abc")
    end

    it "does not require an embed URL for non-live videos" do
      expect(build(:video, kind: :standalone, live_embed_url: nil)).to be_valid
    end

    it "#embed? is true only for a live with an embed URL" do
      expect(build(:video, :live).embed?).to be(true)
      expect(build(:video, kind: :standalone).embed?).to be(false)
    end

    it "#embed_src returns the stored embed URL" do
      expect(build(:video, :live).embed_src).to eq("https://www.youtube.com/embed/O8bnDdWsk8Q")
    end
  end

  describe "maturity_rating" do
    it { is_expected.to define_enum_for(:maturity_rating).with_values(L: 0, A6: 1, A10: 2, A12: 3, A14: 4, A16: 5, A18: 6) }

    it "is valid without a duration (upload time)" do
      expect(build(:video, duration_seconds: nil)).to be_valid
    end
  end

  describe "attachments" do
    it { expect(described_class.reflect_on_attachment(:thumbnail)).to be_present }
    it { expect(described_class.reflect_on_attachment(:file)).to be_present }

    it "attaches a thumbnail via the trait" do
      expect(build(:video, :with_thumbnail).thumbnail).to be_attached
    end
  end

  describe "scopes" do
    describe ".recent" do
      it "orders by created_at descending" do
        older = create(:video, created_at: 2.days.ago)
        newer = create(:video, created_at: 1.hour.ago)
        expect(Video.recent.to_a).to eq([ newer, older ])
      end
    end
  end

  # --- Restricted visibility (feature 006) ---

  describe "restricted visibility" do
    it "defines the fourth enum value" do
      video = build(:video, visibility: :restricted, maturity_rating: :A18)
      expect(video.visibility_restricted?).to be(true)
    end

    it "requires A18 for restricted titles" do
      video = build(:video, visibility: :restricted, maturity_rating: :A14)
      expect(video).not_to be_valid
      expect(video.errors[:visibility]).to include("restricted titles must be rated A18")
    end

    it "is valid when restricted with A18" do
      expect(build(:video, visibility: :restricted, maturity_rating: :A18)).to be_valid
    end
  end

  # --- Player (feature 005) — visibility rules live in VideoPolicy (006) ---

  describe "#related" do
    let(:locked) { AuthContext.new(user: create(:user), pin_unlocked: false) }
    let(:unlocked) { AuthContext.new(user: create(:user), pin_unlocked: true) }

    it "returns recent public videos of the same kind, excluding itself" do
      current = create(:video, kind: :standalone, visibility: :public)
      same = create(:video, kind: :standalone, visibility: :public)
      create(:video, kind: :feature, visibility: :public)
      create(:video, kind: :standalone, visibility: :private)

      related = current.related(locked, limit: 12)
      expect(related).to include(same)
      expect(related).not_to include(current)
      expect(related.map(&:kind).uniq).to eq([ "standalone" ])
      expect(related.select(&:visibility_private?)).to be_empty
    end

    it "includes restricted titles only for an unlocked context (separate cache keys)" do
      current = create(:video, kind: :standalone, visibility: :public)
      restricted = create(:video, kind: :standalone, visibility: :restricted, maturity_rating: :A18)

      expect(current.related(locked)).not_to include(restricted)
      expect(current.related(unlocked)).to include(restricted)
      # and the locked list is still restricted-free after the unlocked call
      expect(current.related(locked)).not_to include(restricted)
    end
  end

  describe "cache invalidation (Constitution VI)" do
    # Test env uses :null_store; use a real in-memory store to observe caching.
    let(:store) { ActiveSupport::Cache::MemoryStore.new }
    before { allow(Rails).to receive(:cache).and_return(store) }

    it "busts the slug cache and bumps the kind version on update" do
      video = create(:video, kind: :standalone, visibility: :public)
      Rails.cache.write([ "video", video.slug ], video.id)
      before = Video.cache_version([ "videos", "standalone" ])

      video.update!(title: "A New Title For Cache Bust")

      expect(Rails.cache.read([ "video", video.slug ])).to be_nil
      expect(Video.cache_version([ "videos", "standalone" ])).to be > before
    end
  end

  describe "#display_title" do
    def episode_video(episode_title:, position: 4)
      serie = create(:serie, title: "Named Show")
      season = serie.seasons.create!(position: 1, name: "Season 1")
      video = create(:video, kind: :episode, title: "Named Show S1E#{position}")
      season.episodes.create!(video: video, title: episode_title, position: position)
      video
    end

    it "shows E-number — episode title when the episode was really named" do
      expect(episode_video(episode_title: "The Heist").display_title).to eq("E4 — The Heist")
    end

    it "keeps the machine name for the auto 'Episode N' placeholder title" do
      expect(episode_video(episode_title: "Episode 4").display_title).to eq("Named Show S1E4")
    end

    it "keeps the plain title for non-episode videos" do
      expect(build(:video, kind: :standalone, title: "Just a Clip").display_title).to eq("Just a Clip")
    end

    it "falls back to the video title for an episode video with no episode row" do
      expect(build(:video, kind: :episode, title: "Orphan S1E1").display_title).to eq("Orphan S1E1")
    end
  end

  describe "skip markers (#effective_opening_time / #effective_ending_time)" do
    def episode_of(serie_attrs, video_attrs)
      serie = create(:serie, **serie_attrs)
      season = serie.seasons.create!(position: 1, name: "Season 1")
      video = create(:video, kind: :episode, **video_attrs)
      season.episodes.create!(video: video, title: "Ep", position: 1)
      video
    end

    it "falls back to the serie's markers when the video has none" do
      video = episode_of({ opening_time: 30, ending_time: 1200 }, {})
      expect(video.effective_opening_time).to eq(30)
      expect(video.effective_ending_time).to eq(1200)
    end

    it "prefers the video's own markers over the serie's" do
      video = episode_of({ opening_time: 30, ending_time: 1200 },
                         { opening_time: 45, ending_time: 1100 })
      expect(video.effective_opening_time).to eq(45)
      expect(video.effective_ending_time).to eq(1100)
    end

    it "is nil when neither carries markers (standalone too)" do
      expect(build(:video).effective_opening_time).to be_nil
      expect(build(:video).effective_ending_time).to be_nil
    end
  end

  describe "#attach_generated_thumbnail! (backfill)" do
    def fake_frame
      file = Tempfile.new([ "frame", ".jpg" ], binmode: true)
      file.write("\xFF\xD8".b + "jpeg-bytes")
      file.rewind
      file
    end

    let(:video) { create(:video, :with_file) }
    let(:extractor) do
      klass = class_double(VideoFrameExtractor)
      allow(klass).to receive(:call)
        .and_return(VideoFrameExtractor::Result.new(frames: [ fake_frame ], error: nil))
      klass
    end

    it "attaches the extracted frame as the thumbnail" do
      expect(video.attach_generated_thumbnail!(extractor: extractor)).to be(true)
      expect(video.thumbnail).to be_attached
    end

    it "skips a video that already has a thumbnail" do
      video = create(:video, :with_file, :with_thumbnail)

      expect(video.attach_generated_thumbnail!(extractor: extractor)).to be(false)
    end

    it "skips a video with no file" do
      expect(create(:video).attach_generated_thumbnail!(extractor: extractor)).to be(false)
    end

    it "returns false when no frame could be extracted" do
      empty = class_double(VideoFrameExtractor)
      allow(empty).to receive(:call)
        .and_return(VideoFrameExtractor::Result.new(frames: [], error: "ffmpeg is unavailable"))

      expect(video.attach_generated_thumbnail!(extractor: empty)).to be(false)
      expect(video.thumbnail).not_to be_attached
    end
  end

  # --- Search (pg_trgm): search_text + Video.search ---

  describe "search_text" do
    let(:video) { create(:video, title: "Pilot Night") }

    def search_text = video.reload.search_text

    it "starts as the video's own title, lowercased" do
      expect(search_text).to eq("pilot night")
    end

    it "borrows its serie's title while it is an episode, following renames" do
      serie = Serie.create!(title: "Galaxy Rangers")
      episode = create(:episode, season: create(:season, serie: serie), video: video)
      expect(search_text).to eq("pilot night galaxy rangers")

      serie.update!(title: "Star Rangers")
      expect(search_text).to eq("pilot night star rangers")

      episode.destroy!
      expect(search_text).to eq("pilot night")
    end

    it "borrows its movie's title, and hands it over when the movie is re-pointed" do
      movie = create(:movie, title: "Galaxy Quest", video: video)
      expect(search_text).to eq("pilot night galaxy quest")

      movie.update!(title: "Galaxy Quest II")
      expect(search_text).to eq("pilot night galaxy quest ii")

      other = create(:video, title: "Director's Cut")
      movie.update!(video: other)
      expect(search_text).to eq("pilot night")
      expect(other.reload.search_text).to eq("director's cut galaxy quest ii")

      movie.destroy!
      expect(other.reload.search_text).to eq("director's cut")
    end

    # A video can sit in any number of playlists, so their titles would grow the
    # string without bound; playlists are searched on their own (Playlist.search).
    it "never borrows playlist titles" do
      create(:playlist_item, playlist: create(:playlist, title: "Galaxy Mix", visibility: :public), video: video)
      expect(search_text).to eq("pilot night")
    end

    it "is refreshed even for a video that would fail its own validations" do
      video.update_columns(visibility: Video.visibilities[:restricted], maturity_rating: Video.maturity_ratings[:A14])
      expect(video.reload).not_to be_valid

      create(:movie, title: "Galaxy Quest", video: video)
      expect(search_text).to eq("pilot night galaxy quest")
    end
  end

  describe ".search" do
    it "matches any borrowed title and tolerates typos" do
      episode = create(:video, title: "Rangers S1E1")
      create(:episode, season: create(:season, serie: Serie.create!(title: "Galaxy Rangers")), video: episode)
      own = create(:video, title: "Galaxy Warriors")
      create(:video, title: "Unrelated Clip")

      expect(Video.search("galaxy")).to contain_exactly(own, episode)
      expect(Video.search("GALXY warriors")).to eq([ own ])
    end

    it "puts the best match first" do
      close = create(:video, title: "Galaxy Warrior")
      exact = create(:video, title: "Galaxy Warriors")

      expect(Video.search("galaxy warriors")).to eq([ exact, close ])
    end

    it "matches nothing for a query with no letters or digits" do
      create(:video, title: "Percent Test")
      expect(Video.search("%")).to be_empty
    end
  end
end
