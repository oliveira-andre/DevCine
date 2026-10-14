require 'rails_helper'

RSpec.describe Serie, type: :model do
  it "has a valid factory" do
    expect(build(:serie)).to be_valid
  end

  describe "validations" do
    it { is_expected.to validate_presence_of(:title) }
  end

  describe "associations" do
    it { is_expected.to have_many(:seasons).dependent(:destroy) }
    it { is_expected.to have_many(:videos).through(:seasons) }
  end

  describe "attachments" do
    it { expect(described_class.reflect_on_attachment(:poster)).to be_present }
    it { expect(described_class.reflect_on_attachment(:backdrop)).to be_present }

    it "attaches a poster via the trait" do
      expect(build(:serie, :with_poster).poster).to be_attached
    end
  end

  describe ".recent" do
    it "orders by created_at descending" do
      older = create(:serie, created_at: 3.days.ago)
      newer = create(:serie, created_at: 1.hour.ago)
      expect(Serie.recent.to_a).to eq([newer, older])
    end
  end

  describe ".last_watched_by" do
    let(:user) { create(:user) }

    def episode_video_of(serie)
      season = serie.seasons.first || create(:season, serie: serie)
      create(:episode, season: season, video: create(:video, kind: :episode)).video
    end

    it "returns a serie once however many of its episodes were watched" do
      serie = create(:serie)
      2.times { create(:watch_progress, user: user, video: episode_video_of(serie)) }

      expect(Serie.last_watched_by(user).to_a).to eq([ serie ])
    end

    it "orders series by their most recently watched episode" do
      older = create(:serie)
      newer = create(:serie)
      create(:watch_progress, user: user, video: episode_video_of(newer), updated_at: 3.days.ago)
      create(:watch_progress, user: user, video: episode_video_of(older), updated_at: 2.days.ago)
      # Rewatching any episode of `newer` lifts the whole serie back to the front.
      create(:watch_progress, user: user, video: episode_video_of(newer), updated_at: 1.hour.ago)

      expect(Serie.last_watched_by(user).to_a).to eq([ newer, older ])
    end

    it "ignores other users' history and unwatched series" do
      create(:serie)
      someone_elses = create(:serie)
      create(:watch_progress, user: create(:user), video: episode_video_of(someone_elses))

      expect(Serie.last_watched_by(user)).to be_empty
    end
  end
end
