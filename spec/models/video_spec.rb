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
end
