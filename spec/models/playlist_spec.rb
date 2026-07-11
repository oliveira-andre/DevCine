require 'rails_helper'

RSpec.describe Playlist, type: :model do
  it "has a valid factory" do
    expect(build(:playlist)).to be_valid
  end

  it { is_expected.to belong_to(:user) }
  it { is_expected.to have_many(:playlist_items).dependent(:destroy) }
  it { is_expected.to have_many(:videos).through(:playlist_items) }
  it { is_expected.to define_enum_for(:visibility).with_values(private: 0, public: 1, unlisted: 2).with_prefix }

  describe "#videos_count" do
    it "counts the playlist's videos" do
      playlist = create(:playlist, :with_videos, videos_count: 3)
      expect(playlist.videos_count).to eq(3)
    end

    it "is 0 for an empty playlist" do
      expect(create(:playlist).videos_count).to eq(0)
    end
  end
end
