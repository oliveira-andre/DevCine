require 'rails_helper'

# Per-title audio/subtitle memory: one row per (user, title). The title is the
# Serie for episodes, the Movie for features, the Video itself for standalones.
RSpec.describe PlaybackPreference, type: :model do
  it "allows only one row per user and title" do
    serie = create(:serie)
    user = create(:user)
    create(:playback_preference, user: user, watchable: serie)

    duplicate = build(:playback_preference, user: user, watchable: serie)
    expect(duplicate).not_to be_valid
    expect(duplicate.errors[:user_id]).to be_present
  end

  it "rejects watchable types outside Serie/Movie/Video" do
    preference = build(:playback_preference, watchable: create(:user))
    expect(preference).not_to be_valid
    expect(preference.errors[:watchable_type]).to be_present
  end

  it "is destroyed with its user" do
    preference = create(:playback_preference)
    expect { preference.user.destroy }.to change(described_class, :count).by(-1)
  end

  describe "Video#preference_scope" do
    it "resolves to the serie for an episode" do
      video = create(:video)
      season = create(:season)
      create(:episode, season: season, video: video)
      expect(video.preference_scope).to eq(season.serie)
    end

    it "resolves to the movie for a feature" do
      movie = create(:movie)
      expect(movie.video.preference_scope).to eq(movie)
    end

    it "resolves to the video itself for a standalone" do
      video = create(:video, kind: :standalone)
      expect(video.preference_scope).to eq(video)
    end
  end
end
