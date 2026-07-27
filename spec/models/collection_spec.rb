require 'rails_helper'

# The Collection concern (feature 007), exercised through Serie and Playlist.
RSpec.describe Collection do
  let(:viewer) { create(:user) }

  def ctx(user = viewer, unlocked: false)
    AuthContext.new(user: user, pin_unlocked: unlocked)
  end

  # Build a serie with the given per-season video lists (each an array of videos,
  # in episode order). Returns [serie, seasons].
  def build_serie(*season_video_lists)
    serie = create(:serie)
    seasons = season_video_lists.each_with_index.map do |videos, si|
      season = create(:season, serie: serie, position: si + 1)
      videos.each_with_index do |video, ei|
        create(:episode, season: season, video: video, position: ei + 1)
      end
      season
    end
    [ serie, seasons ]
  end

  describe "canonical ordering" do
    it "orders a serie by season.position then episode.position" do
      a, b, c, d = create_list(:video, 4)
      serie, = build_serie([ c, d ], [ a, b ]) # season 1: c,d ; season 2: a,b
      expect(serie.ordered_video_ids(ctx)).to eq([ c.id, d.id, a.id, b.id ])
    end

    it "orders a playlist by playlist_item.position" do
      v1, v2, v3 = create_list(:video, 3)
      playlist = create(:playlist)
      create(:playlist_item, playlist: playlist, video: v3, position: 3)
      create(:playlist_item, playlist: playlist, video: v1, position: 1)
      create(:playlist_item, playlist: playlist, video: v2, position: 2)
      expect(playlist.ordered_video_ids(ctx)).to eq([ v1.id, v2.id, v3.id ])
    end
  end

  describe "visibility filtering (VideoPolicy::Scope)" do
    it "excludes restricted videos while locked and includes them when unlocked" do
      public_v = create(:video, visibility: :public)
      restricted_v = create(:video, visibility: :restricted, maturity_rating: :A18)
      serie, = build_serie([ public_v, restricted_v ])

      expect(serie.ordered_video_ids(ctx)).to eq([ public_v.id ])
      expect(serie.ordered_video_ids(ctx(unlocked: true))).to eq([ public_v.id, restricted_v.id ])
    end

    it "excludes a private video not owned by the viewer" do
      public_v = create(:video, visibility: :public)
      private_v = create(:video, visibility: :private, uploader: create(:user))
      playlist = create(:playlist)
      create(:playlist_item, playlist: playlist, video: public_v, position: 1)
      create(:playlist_item, playlist: playlist, video: private_v, position: 2)

      expect(playlist.ordered_video_ids(ctx)).to eq([ public_v.id ])
    end
  end

  describe "#first_video / #play_target / #current_video" do
    let(:v1) { create(:video, :with_thumbnail, visibility: :public) }
    let(:v2) { create(:video, :with_thumbnail, visibility: :public) }
    let!(:serie) { build_serie([ v1, v2 ]).first }

    it "first_video is the first visible video" do
      expect(serie.first_video(ctx)).to eq(v1)
    end

    it "current_video is the most-recently-watched visible video, else nil" do
      expect(serie.current_video(viewer, ctx)).to be_nil
      VideoView.record!(viewer, v1)
      VideoView.record!(viewer, v2)
      expect(serie.current_video(viewer, ctx)).to eq(v2)
    end

    it "play_target resumes the current video, else the first" do
      expect(serie.play_target(viewer, ctx)).to eq(v1)
      VideoView.record!(viewer, v2)
      expect(serie.play_target(viewer, ctx)).to eq(v2)
    end

    it "play_target is nil for an empty collection" do
      expect(create(:playlist).play_target(viewer, ctx)).to be_nil
    end

    it "never returns a video the viewer cannot see as current" do
      restricted = create(:video, visibility: :restricted, maturity_rating: :A18)
      s2, = build_serie([ v1, restricted ])
      VideoView.record!(viewer, restricted) # watched while unlocked, now locked
      expect(s2.current_video(viewer, ctx)).to eq(v1).or be_nil
      expect(s2.current_video(viewer, ctx)).not_to eq(restricted)
    end
  end

  describe "caching (Constitution VI)" do
    # Test env uses :null_store; use a real in-memory store to observe caching.
    let(:store) { ActiveSupport::Cache::MemoryStore.new }
    before { allow(Rails).to receive(:cache).and_return(store) }

    let(:v1) { create(:video, visibility: :public) }
    let!(:serie) { build_serie([ v1 ]).first }

    it "serves repeat reads from cache without re-querying" do
      serie.ordered_video_ids(ctx) # prime
      expect(Episode).not_to receive(:joins)
      expect(serie.ordered_video_ids(ctx)).to eq([ v1.id ])
    end

    it "invalidates when an episode is added" do
      expect(serie.ordered_video_ids(ctx)).to eq([ v1.id ])
      v2 = create(:video, visibility: :public)
      create(:episode, season: serie.seasons.first, video: v2, position: 2)
      expect(serie.ordered_video_ids(ctx)).to eq([ v1.id, v2.id ])
    end

    it "invalidates current_video when the viewer watches a new episode" do
      v2 = create(:video, visibility: :public)
      create(:episode, season: serie.seasons.first, video: v2, position: 2)
      expect(serie.current_video(viewer, ctx)).to be_nil
      VideoView.record!(viewer, v2)
      expect(serie.current_video(viewer, ctx)).to eq(v2)
    end
  end
end
