require 'rails_helper'

RSpec.describe Playlist, type: :model do
  it "has a valid factory" do
    expect(build(:playlist)).to be_valid
  end

  it { is_expected.to belong_to(:user) }
  it { is_expected.to have_many(:playlist_items).dependent(:destroy) }
  it { is_expected.to have_many(:videos).through(:playlist_items) }
  it { is_expected.to define_enum_for(:visibility).with_values(private: 0, public: 1, unlisted: 2).with_prefix }

  describe "title validation (feature 008)" do
    let(:user) { create(:user) }

    it "requires a present title" do
      expect(Playlist.new(user: user, title: "")).not_to be_valid
      expect(Playlist.new(user: user, title: "   ")).not_to be_valid
    end

    it "bounds the title to 100 characters" do
      expect(Playlist.new(user: user, title: "a" * 101)).not_to be_valid
      expect(Playlist.new(user: user, title: "a" * 100)).to be_valid
    end
  end

  describe "#videos_count" do
    it "counts the playlist's videos" do
      playlist = create(:playlist, :with_videos, videos_count: 3)
      expect(playlist.videos_count).to eq(3)
    end

    it "is 0 for an empty playlist" do
      expect(create(:playlist).videos_count).to eq(0)
    end
  end

  describe ".discoverable" do
    it "is public playlists only — unlisted stays reachable by link but unlisted" do
      public_list = create(:playlist, visibility: :public)
      create(:playlist, visibility: :unlisted)
      create(:playlist, visibility: :private)

      expect(Playlist.discoverable).to contain_exactly(public_list)
    end
  end

  describe "#save_copy_for" do
    let(:owner) { create(:user) }
    let(:saver) { create(:user) }
    let(:auth) { AuthContext.new(user: saver, pin_unlocked: false) }
    let(:source) { create(:playlist, user: owner, title: "Road Trip", visibility: :public) }

    def add(video, position)
      create(:playlist_item, playlist: source, video: video, position: position)
    end

    it "copies the members in order under the saving user" do
      first = create(:video, title: "First", visibility: :public)
      second = create(:video, title: "Second", visibility: :public)
      add(first, 1)
      add(second, 2)

      copy = source.save_copy_for(saver, auth)

      expect(copy.user).to eq(saver)
      expect(copy.title).to eq("Road Trip")
      expect(copy.cloned_from).to eq(source)
      expect(copy.playlist_items.order(:position).map(&:video)).to eq([ first, second ])
    end

    it "is public, so a saved copy stays shareable like any created playlist" do
      expect(source.save_copy_for(saver, auth)).to be_visibility_public
    end

    it "is idempotent — saving twice returns the same copy" do
      first_copy = source.save_copy_for(saver, auth)
      second_copy = source.save_copy_for(saver, auth)

      expect(second_copy).to eq(first_copy)
      expect(saver.playlists.where(cloned_from: source).count).to eq(1)
    end

    it "gives each user their own copy" do
      other = create(:user)

      expect(source.save_copy_for(saver, auth)).not_to eq(source.save_copy_for(other, auth))
    end

    # Saving must not become a back door to titles the saver cannot see.
    it "leaves out members the saver is not allowed to see" do
      visible = create(:video, title: "Visible", visibility: :public)
      add(visible, 1)
      add(create(:video, title: "Someone's Private", visibility: :private), 2)
      add(create(:video, title: "Locked", visibility: :restricted, maturity_rating: :A18), 3)

      copy = source.save_copy_for(saver, auth)

      expect(copy.videos).to contain_exactly(visible)
    end

    it "includes restricted members when the saver is PIN-unlocked" do
      locked = create(:video, title: "Locked", visibility: :restricted, maturity_rating: :A18)
      add(locked, 1)
      unlocked = AuthContext.new(user: saver, pin_unlocked: true)

      expect(source.save_copy_for(saver, unlocked).videos).to include(locked)
    end

    it "copies an empty playlist as an empty playlist" do
      expect(source.save_copy_for(saver, auth).videos_count).to eq(0)
    end
  end

  describe "#clone_for" do
    it "finds the copy a given user saved, and nothing for anyone else" do
      source = create(:playlist, visibility: :public)
      saver = create(:user)
      copy = source.save_copy_for(saver, AuthContext.new(user: saver, pin_unlocked: false))

      expect(source.clone_for(saver)).to eq(copy)
      expect(source.clone_for(create(:user))).to be_nil
      expect(source.clone_for(nil)).to be_nil
    end
  end

  # The FK nullifies rather than cascading: deleting an original must not
  # delete the copies people made of it.
  it "keeps a saved copy when the original is deleted" do
    source = create(:playlist, visibility: :public)
    saver = create(:user)
    copy = source.save_copy_for(saver, AuthContext.new(user: saver, pin_unlocked: false))

    source.destroy

    expect(copy.reload).to be_persisted
    expect(copy.cloned_from_id).to be_nil
  end
end
